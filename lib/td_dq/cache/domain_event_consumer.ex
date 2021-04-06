defmodule TdDq.Cache.DomainEventConsumer do
  @moduledoc """
  Module to manage domain related data structure information.
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  require Logger

  @index_worker Application.compile_env(:td_dq, :index_worker)

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  ## EventStream.Consumer Callbacks

  @impl true
  def consume(events) do
    GenServer.cast(__MODULE__, {:consume, events})
  end

  ## GenServer callbacks

  @impl true
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    {:ok, state}
  end

  @impl true
  def handle_cast({:consume, events}, state) do
    case Enum.any?(events, &(&1.event == "domain_updated")) do
      true -> @index_worker.reindex()
      _ -> :ok
    end

    {:noreply, state}
  end
end
