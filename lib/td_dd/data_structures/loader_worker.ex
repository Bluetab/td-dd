defmodule TdDd.Loader.LoaderWorker do
  @moduledoc """
  GenServer to handle bulk loading data dictionary
  """

  use GenServer

  alias TdDd.Loader

  require Logger

  @index_worker Application.get_env(:td_dd, :index_worker)

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  def load(structures, fields, relations, audit) do
    GenServer.cast(TdDd.Loader.LoaderWorker, {:load, structures, fields, relations, audit})
  end

  def ping do
    GenServer.call(TdDd.Loader.LoaderWorker, :ping)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:load, structures, fields, relations, %{last_change_at: ts} = audit}, state) do
    Logger.info("Bulk loading data structures")
    start_time = DateTime.utc_now()
    multi = Loader.load(structures, fields, relations, audit)
    ms = DateTime.diff(DateTime.utc_now(), start_time, :millisecond)
    post_process(multi, ts, ms)
    {:noreply, state}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  defp post_process(
         {:ok,
          %{
            structures: structures,
            updated_versions: updated_versions,
            inserted_versions: inserted_versions,
            deleted_structures: deleted_structures
          }},
         ts,
         ms
       ) do
    upsert_count =
      structures
      |> Enum.filter(&(&1.last_change_at == ts))
      |> Enum.count()

    update_count = Enum.count(updated_versions)
    insert_count = Enum.count(inserted_versions)
    delete_count = Enum.count(deleted_structures)

    Logger.info(
      "Bulk load process completed in #{ms}ms (*#{upsert_count}S +#{insert_count}V *#{
        update_count
      }V -#{delete_count}V)"
    )

    if upsert_count + update_count + insert_count + delete_count > 0 do
      deleted_structures
      |> Enum.concat(structures)
      |> @index_worker.reindex
    end
  end

  defp post_process({:error, failed_operation, _failed_value, _changes_so_far}, _ts, ms) do
    Logger.warn("Bulk load process failed after #{ms}ms (operation #{failed_operation})")
  end

  defp post_process(_, _, _) do
    Logger.error("Unexpected multi response")
  end
end
