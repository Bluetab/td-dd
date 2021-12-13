defmodule TdDq.Implementations.BulkLoad do
  @moduledoc """
  Bulk Load Implementations
  """

  alias Ecto.Changeset
  alias TdDdWeb.ErrorHelpers
  alias TdDq.Implementations
  alias TdDq.Rules

  @index_worker Application.compile_env(:td_dd, :dq_index_worker)

  @required_headers [
    "rule_name",
    "implementation_key",
    "result_type",
    "goal",
    "minimum"
  ]
  @optional_headers ["template"]

  @headers @required_headers ++ @optional_headers

  @default_implementation %{
    "dataset" => [],
    "executable" => false,
    "implementation_type" => "draft",
    "population" => [],
    "validations" => []
  }

  require Logger

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
      rule = Rules.get_rule_by_name(imp["rule_name"])
      imp = enrich_implementation(imp)

      case Implementations.create_implementation(rule, imp, claims, true) do
        {:ok, %{implementation: %{id: id}}} ->
          %{acc | ids: [id | acc.ids]}

        {:error, _, changeset, _} ->
          error = Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)
          implementation_key = Changeset.get_field(changeset, :implementation_key)

          %{
            acc
            | errors: [%{implementation_key: implementation_key, message: error} | acc.errors]
          }
      end
    end)
    |> Map.update!(:ids, &Enum.reverse(&1))
    |> Map.update!(:errors, &Enum.reverse(&1))
  end

  defp enrich_implementation(implementation) do
    df_name = Map.get(implementation, "template")

    implementation
    |> Enum.reduce(%{"df_content" => %{}}, fn {header, value}, acc ->
      if Enum.member?(@headers, header) do
        Map.put(acc, header, value)
      else
        Map.update!(acc, "df_content", fn content ->
          Map.put(content, header, value)
        end)
      end
    end)
    |> Map.put("df_name", df_name)
    |> Map.delete("template")
    |> Map.merge(@default_implementation)
  end
end