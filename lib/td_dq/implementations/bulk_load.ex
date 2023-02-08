defmodule TdDq.Implementations.BulkLoad do
  @moduledoc """
  Bulk Load Implementations
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias TdCache.DomainCache
  alias TdCache.TemplateCache
  alias TdDdWeb.ErrorHelpers
  alias TdDq.Implementations
  alias TdDq.Rules

  require Logger

  @index_worker Application.compile_env(:td_dd, :dq_index_worker)

  @required_headers [
    "implementation_key",
    "result_type",
    "goal",
    "minimum"
  ]

  @optional_headers ["template", "rule_name", "domain_external_id", "domain_id"]

  @headers @required_headers ++ @optional_headers

  @basic_implementation %{
    "dataset" => [],
    "executable" => false,
    "implementation_type" => "basic",
    "population" => [],
    "validations" => []
  }

  def required_headers, do: @required_headers

  def bulk_load(implementations, claims) do
    bulk_load(implementations, claims, false)
  end

  def bulk_load(implementations, claims, auto_publish) do
    Logger.info("Loading Implementations...")

    Timer.time(
      fn -> do_bulk_load(implementations, claims, auto_publish) end,
      fn millis, _ -> Logger.info("Implementation loaded in #{millis}ms") end
    )
  end

  defp do_bulk_load(implementations, claims, auto_publish) do
    %{ids: ids} = result = upsert_implementations(implementations, claims, auto_publish)
    @index_worker.reindex_implementations(ids)
    {:ok, result}
  end

  defp upsert_implementations(implementations_params, claims, auto_publish) do
    new_status = if auto_publish, do: "published", else: "draft"

    %{reversed_impl_keys: reversed_impl_keys, params_by_impl_key: params_by_impl_key, errors: errors} = Enum.reduce(
      implementations_params,
      %{reversed_impl_keys: [], params_by_impl_key: %{}, errors: []},
      fn
        %{"implementation_key" => implementation_key} = ip,
        %{reversed_impl_keys: reversed_impl_keys, params_by_impl_key: params_by_impl_key, errors: errors} = acc ->
          ip
          |> process_params()
          |> case do
            {:ok, processed_params} ->
              %{
                acc |
                  params_by_impl_key:
                    processed_params
                    |> Map.put("status", new_status)
                    |> then(&Map.put(params_by_impl_key, implementation_key, &1)),
                  reversed_impl_keys: [implementation_key | reversed_impl_keys]
              }
            {:error, %{message: _message} = error} ->
              Kernel.put_in(acc[:errors], [error | errors])
            {:error, error_without_enclosing_message} ->
              Kernel.put_in(acc[:errors], [%{message: error_without_enclosing_message} | errors])
          end
    end)

    ordered_impl_keys = Enum.reverse(reversed_impl_keys)
    %{existing_implementations_struct: existing_implementations_struct, update_results: results_so_far} =
    Implementations.Implementation
    |> where([i], i.implementation_key in ^ordered_impl_keys)
    |> select(
      [i],
      %{
        i |
        highest_version_rank: fragment(
          "rank() over (partition by implementation_key order by version desc)"
        )
      }
    )
    |> subquery()
    |> where([i_with_rank], i_with_rank.highest_version_rank == 1)
    |> TdDd.Repo.all()
    |> update_implementations(%{ids: [], errors: errors}, params_by_impl_key, claims)

    existing_implementations_keys = Enum.map(existing_implementations_struct, & &1.implementation_key)
    ordered_impl_keys -- existing_implementations_keys
    # Take values from params_by_impl_key in order
    |> Enum.map(&params_by_impl_key[&1])
    |> create_implementations(results_so_far, claims)
    |> Map.update!(:ids, &Enum.reverse/1)
    |> Map.update!(:errors, &Enum.reverse/1)
  end

  defp make_implementations_errors(result, acc) do
    case result do
      {:ok, %{implementation: %{id: id}}} ->
        %{acc | ids: [id | acc.ids]}

      {:error, _, changeset, _} ->
        error = Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)
        implementation_key = Changeset.get_field(changeset, :implementation_key)

        %{
          acc
          | errors: [%{implementation_key: implementation_key, message: error} | acc.errors]
        }

      {:error, {implementation_key, error}} ->
        %{
          acc
          | errors: [
              %{implementation_key: implementation_key, message: %{implementation: [error]}}
              | acc.errors
            ]
        }
    end
  end

  defp update_implementations(existing_implementations_struct, results_so_far, params_by_impl_key, claims) do
    results =
      existing_implementations_struct
      |> Enum.filter(& &1.status not in [:versioned, :pending_approval, :rejected])
      |> Enum.reduce(
        results_so_far,
        fn %{implementation_key: impl_key} = existing_implementation, acc ->
          existing_implementation
          |> Implementations.update_implementation(params_by_impl_key[impl_key], claims)
          |> make_implementations_errors(acc)
        end
      )
    %{update_results: results, existing_implementations_struct: existing_implementations_struct}
  end

  defp process_params(%{"implementation_key" => imp_key} = params) do
    with {:ok, imp} <- enrich_implementation(params),
           {:ok, imp} <- maybe_put_domain_id(imp) do
      format_df_content(imp)
    else
      {:error, error} ->
        {:error, %{implementation_key: imp_key, message: error}}
    end
  end

  defp create_implementations(processed_params_imps, results_so_far, claims) do
    Enum.reduce(processed_params_imps, results_so_far, fn processed_params, acc ->
      processed_params
      |> Map.put("version", 1)
      |> create_implementation(claims)
      |> make_implementations_errors(acc)
    end)
  end

  defp create_implementation(%{"rule_name" => rule_name} = imp, claims)
       when is_binary(rule_name) and rule_name != "" do
    case Rules.get_rule_by_name(rule_name) do
      nil -> {:error, {imp["implementation_key"], "rule #{rule_name} does not exist"}}
      rule -> Implementations.create_implementation(rule, imp, claims, true)
    end
  end

  defp create_implementation(imp, claims) do
    Implementations.create_ruleless_implementation(imp, claims, true)
  end

  defp enrich_implementation(implementation) do
    implementation
    |> Enum.reduce(%{"df_content" => %{}}, fn {header, value}, acc ->
      if Enum.member?(@headers, header) do
        Map.put(acc, header, value)
      else
        Map.update!(acc, "df_content", &Map.put(&1, header, value))
      end
    end)
    |> ensure_template()
    |> Map.merge(@basic_implementation)
    |> then(&{:ok, &1})
  end

  defp ensure_template(%{"df_content" => df_content} = implementation) do
    if Enum.empty?(df_content) or Map.has_key?(implementation, "template") do
      implementation
      |> Map.put("df_name", implementation["template"])
      |> Map.delete("template")
    else
      implementation
    end
  end

  defp maybe_put_domain_id(%{"domain_external_id" => external_id} = params)
       when is_binary(external_id) and external_id != "" do
    case get_domain_id_by_external_id(external_id) do
      {:ok, domain_id} -> {:ok, Map.put(params, "domain_id", domain_id)}
      {:error, msg} -> {:error, %{"domain_external_id" => [msg]}}
    end
  end

  defp maybe_put_domain_id(%{"domain_id" => domain_id} = params)
       when is_binary(domain_id) do
    {:ok, Map.put(params, "domain_id", String.to_integer(domain_id))}
  end

  defp maybe_put_domain_id(params) do
    {:ok, params}
  end

  defp get_domain_id_by_external_id(external_id) do
    case DomainCache.external_id_to_id(external_id) do
      :error -> {:error, "Domain with external id #{external_id} doesn't exist"}
      domain_id -> domain_id
    end
  end

  defp format_df_content(%{"df_name" => template_name, "df_content" => df_content} = params)
       when is_binary(template_name) do
    case TemplateCache.get_by_name!(template_name) do
      nil ->
        {:error, %{"template" => ["Template #{template_name} doesn't exist"]}}

      template ->
        template
        |> Map.get(:content)
        |> Enum.reduce([], fn %{"fields" => fields}, acc -> acc ++ fields end)
        |> Enum.filter(fn %{"name" => field_name} -> Map.has_key?(df_content, field_name) end)
        |> then(&format_df_content(params, &1))
    end
  end

  defp format_df_content(params), do: {:ok, params}

  defp format_df_content(%{"df_content" => df_content} = params, template_fields) do
    df_content
    |> Enum.reduce_while(
      {:ok, df_content},
      fn {df_field_name, _} = entity, {:ok, df_content_aux} ->
        field_meta =
          Enum.find(
            template_fields,
            fn field_meta -> Map.get(field_meta, "name") == df_field_name end
          )

        case field_meta do
          nil ->
            {:halt,
             {:error, %{"df_content" => ["The field #{df_field_name} doesn't exist in template"]}}}

          field_meta ->
            format_df_field(df_content_aux, entity, field_meta)
        end
      end
    )
    |> case do
      {:ok, df_content} -> {:ok, Map.put(params, "df_content", df_content)}
      error -> error
    end
  end

  defp format_df_field(df_content, {df_field_name, domain_external_id}, %{"type" => "domain"}) do
    if domain_external_id == "" do
      {:cont, {:ok, Map.put(df_content, df_field_name, nil)}}
    else
      case get_domain_id_by_external_id(domain_external_id) do
        {:error, msg} -> {:halt, {:error, %{"df_content.#{df_field_name}" => [msg]}}}
        {:ok, domain_id} -> {:cont, {:ok, Map.put(df_content, df_field_name, domain_id)}}
      end
    end
  end

  defp format_df_field(df_content, {df_field_name, df_field_value}, %{"type" => "enriched_text"}) do
    if df_field_value == "" do
      {:cont, {:ok, Map.put(df_content, df_field_name, %{})}}
    else
      enriched_structure = %{
        "object" => "value",
        "document" => %{
          "data" => %{},
          "nodes" => [
            %{
              "data" => %{},
              "type" => "paragraph",
              "object" => "block",
              "nodes" => [
                %{
                  "text" => df_field_value,
                  "marks" => [],
                  "object" => "text"
                }
              ]
            }
          ],
          "object" => "document"
        }
      }

      {:cont, {:ok, Map.put(df_content, df_field_name, enriched_structure)}}
    end
  end

  defp format_df_field(df_content, _entity, _template_fields), do: {:cont, {:ok, df_content}}
end
