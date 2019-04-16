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
    GenServer.call(TdDd.Loader.LoaderWorker, {:ping})
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

    case multi do
      {:ok, context} ->
        %{added: added, removed: removed, modified: modified, structures: structures} = context

        upserts =
          structures
          |> Enum.filter(&(&1.last_change_at == ts))
          |> Enum.count()

        Logger.info(
          "Bulk load process completed in #{ms}ms (*#{upserts}S -#{removed}F +#{added}F ~#{
            modified
          }F)"
        )

        if upserts + removed + added + modified > 0 do
          @index_worker.reindex(structures)
        end

      {:error, failed_operation, _failed_value, _changes_so_far} ->
        Logger.warn("Bulk load process failed after #{ms}ms (operation #{failed_operation})")
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:ping}, _from, state) do
    {:reply, :pong, state}
  end
end
