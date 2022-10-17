defmodule TdDq.Implementations.BulkLoad do
  @moduledoc """
  Bulk Load Implementations
  """

  alias Ecto.Changeset
  alias TdCache.DomainCache
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
      imp =
        imp
        |> enrich_implementation()
        |> maybe_put_domain_id()
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
       when is_binary(external_id) do
    case DomainCache.external_id_to_id(external_id) do
      {:ok, domain_id} -> Map.put(params, "domain_id", domain_id)
      :error -> params
    end
  end

  defp maybe_put_domain_id(%{"domain_id" => domain_id} = params)
       when is_binary(domain_id) do
    Map.put(params, "domain_id", String.to_integer(domain_id))
  end

  defp maybe_put_domain_id(params), do: params
end
