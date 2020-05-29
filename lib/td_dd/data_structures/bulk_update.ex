defmodule TdDd.DataStructures.BulkUpdate do
  @moduledoc """
  Support for bulk update of data structures.
  """

  require Logger

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker

  def update_all(ids, %{"df_content" => content}, %{id: user_id} = _user) do
    params = %{"df_content" => content, "last_change_by" => user_id}
    update(ids, params)
  end

  defp update(ids, params) do
    Logger.info("Updating #{length(ids)} data structures...")

    Timer.time(
      fn -> do_update(ids, params) end,
      fn ms, _ -> "Data structures updated in #{ms}ms" end
    )
  end

  defp do_update(ids, params) do
    Repo.transaction(fn ->
      %{id: {:in, ids}}
      |> DataStructures.list_data_structures()
      |> Enum.map(&DataStructure.merge_changeset(&1, params))
      |> Enum.reject(&(&1.changes == %{}))
      |> Enum.reduce_while(%{}, &reduce_changesets/2)
      |> case do
        {:error, error} -> Repo.rollback(error)
        changes -> changes
      end
    end)
    |> on_complete()
  end

  defp reduce_changesets(%{changes: changes} = changeset, %{} = acc) do
    case Repo.update(changeset) do
      {:ok, %{id: id}} -> {:cont, Map.put(acc, id, changes)}
      error -> {:halt, error}
    end
  end

  defp on_complete({:ok, %{} = changes}) do
    ids = Map.keys(changes)
    IndexWorker.reindex(ids)

    # TODO: Audit
    {:ok, ids}
  end

  defp on_complete(errors), do: errors
end
