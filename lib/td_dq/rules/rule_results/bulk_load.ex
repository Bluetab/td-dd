defmodule TdDq.Rules.RuleResults.BulkLoad do
  @moduledoc """
  The Rule Results context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.Repo
  alias TdDq.Cache.RuleLoader
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Audit
  alias TdDq.Rules.RuleResult
  alias TdDq.Rules.RuleResults

  require Logger

  def bulk_load(records) do
    Logger.info("Loading rule results...")

    Timer.time(
      fn -> do_bulk_load(records) end,
      fn millis, _ -> Logger.info("Rule results loaded in #{millis}ms") end
    )
  end

  defp do_bulk_load(records) do
    Multi.new()
    |> Multi.run(:ids, fn _, _ -> bulk_insert(records) end)
    |> Multi.run(:results, fn _, %{ids: ids} -> RuleResults.select_results(ids) end)
    |> Multi.run(:audit, Audit, :rule_results_created, [0])
    |> Repo.transaction()
    |> bulk_refresh()
  end

  defp bulk_refresh(res) do
    with {:ok, %{results: results}} <- res,
         rule_ids <- rule_ids_from_results(results) do
      RuleLoader.refresh(rule_ids)
      res
    end
  end

  defp rule_ids_from_results(results) do
    results
    |> Enum.map(&Map.get(&1, :rule_id))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp bulk_insert(records) do
    implementation_by_key = implementation_by_key(records)

    records
    |> Enum.with_index(2)
    |> Enum.map(fn {params, row_number} -> Map.put(params, "row_number", row_number) end)
    |> Enum.map(&changeset(&1, implementation_by_key))
    |> Enum.reduce_while([], &reduce_changesets/2)
    |> case do
      ids when is_list(ids) -> {:ok, ids}
      error -> error
    end
  end

  defp implementation_by_key(records) do
    keys =
      records
      |> Enum.map(&Map.get(&1, "implementation_key"))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    Implementation
    |> where([ri], ri.implementation_key in ^keys)
    |> select([ri], {ri.implementation_key, ri})
    |> Repo.all()
    |> Map.new()
  end

  defp changeset(%{} = params, %{} = implementation_by_key) do
    with %{"implementation_key" => key} <- params,
         %Implementation{result_type: type, rule_id: rule_id} = impl <-
           Map.get(implementation_by_key, key) do
      RuleResult.changeset(%RuleResult{result_type: type, rule_id: rule_id}, impl, params)
    else
      _ -> RuleResult.changeset(nil, params)
    end
  end

  defp reduce_changesets(%{} = changeset, acc) do
    case Repo.insert(changeset) do
      {:ok, %{id: id}} -> {:cont, [id | acc]}
      error -> {:halt, error}
    end
  end
end
