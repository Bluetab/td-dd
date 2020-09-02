defmodule TdDd.DataStructures.BulkUpdate do
  @moduledoc """
  Support for bulk update of data structures.
  """

  require Logger

  alias Ecto.Multi
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker

  def update_all(ids, %{"df_content" => content}, %{id: user_id} = user) do
    params = %{"df_content" => content, "last_change_by" => user_id}
    Logger.info("Updating #{length(ids)} data structures...")

    Timer.time(
      fn -> do_update(ids, params, user) end,
      fn ms, _ -> "Data structures updated in #{ms}ms" end
    )
  end

  defp do_update(ids, %{} = params, %{id: user_id}) do
    Multi.new()
    |> Multi.run(:updates, &bulk_update(&1, &2, ids, params))
    |> Multi.run(:audit, &audit(&1, &2, user_id))
    |> Repo.transaction()
    |> on_complete()
  end

  defp bulk_update(_repo, _changes_so_far, ids, params) do
    [id: {:in, ids}]
    |> DataStructures.list_data_structures()
    |> Enum.filter(&Map.get(&1, :df_content))
    |> Enum.map(&DataStructure.merge_changeset(&1, params))
    |> Enum.reject(&(&1.changes == %{}))
    |> Enum.reduce_while(%{}, &reduce_changesets/2)
    |> case do
      %{} = res -> {:ok, res}
      error -> error
    end
  end

  defp reduce_changesets(%{} = changeset, %{} = acc) do
    case Repo.update(changeset) do
      {:ok, %{id: id}} -> {:cont, Map.put(acc, id, changeset)}
      error -> {:halt, error}
    end
  end

  defp audit(_repo, %{updates: updates}, user_id) do
    Audit.data_structures_bulk_updated(updates, user_id)
  end

  defp on_complete({:ok, %{updates: updates} = result}) do
    updates
    |> Map.keys()
    |> IndexWorker.reindex()

    {:ok, result}
  end

  defp on_complete(errors), do: errors
end
