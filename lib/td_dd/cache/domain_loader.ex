defmodule TdDd.Cache.DomainLoader do
  @moduledoc """
  Module to manage domain related data structure information.
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  alias TdDd.DataStructures
  alias TdDd.Search.IndexWorker

  require Logger

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
    domain_ids =
      events
      |> Enum.filter(&(&1.event == "domain_updated"))
      |> Enum.map(&Map.take(&1, [:domain, :children_ids]))
      |> Enum.map(fn %{domain: d, children_ids: c_ids} ->
        domain_id = d |> String.split(":") |> List.last()
        children_ids = c_ids |> String.split(",") |> Enum.filter(&(&1 != ""))
        [domain_id | children_ids]
      end)
      |> List.flatten()
      |> Enum.map(&String.to_integer/1)
      |> Enum.uniq()

    unless domain_ids == [] do
      %{}
      |> Map.put(:domain_id, domain_ids)
      |> DataStructures.list_data_structures()
      |> Enum.map(& &1.id)
      |> do_reindex()
    end

    {:noreply, state}
  end

  defp do_reindex(structure_ids) do
    IndexWorker.reindex(structure_ids)
  end
end
