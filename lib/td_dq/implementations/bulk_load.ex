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
  @optional_headers ["df_name"]
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
    Logger.info("Loading Implementations")

    Timer.time(
      fn -> do_bulk_load(implementations, claims) end,
      fn millis, _ -> Logger.info("Implementation loaded in #{millis}ms") end
    )
  end

  defp do_bulk_load(implementations, claims) do
    %{ids: ids} = result = create_implementations(implementations, claims)
    @index_worker.reindex_implementations(ids)
    result
  end

  defp create_implementations(implementations, claims) do
    implementations
    |> Enum.reduce(%{ids: [], errors: []}, fn imp, acc ->
      rule = Rules.get_rule_by_name(imp["rule_name"])
      imp = enrich_implementation(imp)

      case Implementations.create_implementation(rule, imp, claims, true) do
        {:ok, %{implementation: %{id: id}}} ->
          Map.put(acc, :ids, [id | acc.ids])

        {:error, _, changeset, _} ->
          error = Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)
          implementation_key = Changeset.get_field(changeset, :implementation_key)

          Map.put(
            acc,
            :errors,
            acc.errors ++ [%{implementation_key: implementation_key, message: error}]
          )
      end
    end)
    |> Map.update!(:ids, &Enum.reverse(&1))
  end

  defp enrich_implementation(implementation) do
    implementation
    |> Enum.reduce(%{"df_content" => %{}}, fn {head, value}, acc ->
      if Enum.member?(@required_headers ++ @optional_headers, head) do
        Map.put(acc, head, value)
      else
        df_content = Map.put(acc["df_content"], head, value)
        Map.put(acc, "df_content", df_content)
      end
    end)
    |> Map.merge(@default_implementation)
  end
end
