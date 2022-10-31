defmodule TdDq.Implementations.BulkLoad do
  @moduledoc """
  Bulk Load Implementations
  """

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

  @default_implementation %{
    "dataset" => [],
    "executable" => false,
    "implementation_type" => "draft",
    "population" => [],
    "validations" => []
  }

  def required_headers, do: @required_headers

  def bulk_load(implementations, claims) do
    Logger.info("Loading Implementations...")

    Timer.time(
      fn -> do_bulk_load(implementations, claims) end,
      fn millis, _ -> Logger.info("Implementation loaded in #{millis}ms") end
    )
  end

  defp do_bulk_load(implementations, claims) do
    %{ids: ids} = result = create_implementations(implementations, claims)
    @index_worker.reindex_implementations(ids)
    {:ok, result}
  end

  defp create_implementations(implementations, claims) do
    implementations
    |> Enum.reduce(%{ids: [], errors: []}, fn imp, acc ->
      with {:ok, imp} <- enrich_implementation(imp),
           {:ok, imp} <- maybe_put_domain_id(imp),
           {:ok, imp} <- format_df_content(imp) do
        imp =
          imp
          |> Map.put("status", "draft")
          |> Map.put("version", 1)

        case create_implementation(imp, claims) do
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
              | errors: [%{implementation_key: implementation_key, message: error} | acc.errors]
            }
        end
      else
        {:error, error} ->
          %{
            acc
            | errors: [
                %{implementation_key: imp["implementation_key"], message: error} | acc.errors
              ]
          }
      end
    end)
    |> Map.update!(:ids, &Enum.reverse/1)
    |> Map.update!(:errors, &Enum.reverse/1)
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
    imp =
      implementation
      |> Enum.reduce(%{"df_content" => %{}}, fn {header, value}, acc ->
        if Enum.member?(@headers, header) do
          Map.put(acc, header, value)
        else
          Map.update!(acc, "df_content", &Map.put(&1, header, value))
        end
      end)
      |> ensure_template()
      |> Map.merge(@default_implementation)

    {:ok, imp}
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

  defp maybe_put_domain_id(params), do: {:ok, params}

  defp get_domain_id_by_external_id(external_id) do
    case DomainCache.external_id_to_id(external_id) do
      :error -> {:error, "Domain with external id #{external_id} doesn't exists"}
      domain_id -> domain_id
    end
  end

  defp format_df_content(%{"df_name" => template_name, "df_content" => df_content} = params)
       when is_binary(template_name) do
    case TemplateCache.get_by_name!(template_name) do
      nil ->
        {:error, %{"template" => ["Template #{template_name} doesn't exists"]}}

      template ->
        template_fields =
          template
          |> Map.get(:content)
          |> Enum.reduce([], fn %{"fields" => fields}, acc -> acc ++ fields end)
          |> Enum.filter(fn %{"name" => field_name} -> Map.has_key?(df_content, field_name) end)

        format_df_content(params, template_fields)
    end
  end

  defp format_df_content(params), do: {:ok, params}

  defp format_df_content(%{"df_content" => df_content} = params, template_fields) do
    df_content =
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
               {:error,
                %{"df_content" => ["The field #{df_field_name} doesn't exist in template"]}}}

            field_meta ->
              format_df_field(df_content_aux, entity, field_meta)
          end
        end
      )

    case df_content do
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
