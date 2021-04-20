defmodule TdDq.Cache.ImplementationLoader do
  @moduledoc """
  GenServer to put structures used in rule implementations in cache
  """

  use GenServer

  alias TdCache.ImplementationCache
  alias TdDq.Rules.Implementations

  require Logger

  ## Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def ping(timeout \\ 5000) do
    GenServer.call(__MODULE__, :ping, timeout)
  end

  def refresh do
    GenServer.call(__MODULE__, :refresh, 30_000)
  end

  def refresh(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:refresh, ids})
  end

  def refresh(id) do
    refresh([id])
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    unless Application.get_env(:td_dd, :env) == :test do
      Process.send_after(self(), :refresh, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    do_refresh()
    {:noreply, state}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    do_deprecate()
    do_refresh()
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:refresh, ids}, _from, state) do
    do_refresh(ids)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  ## Private functions

  defp do_refresh(ids) do
    case cache_implementations(%{id: {:in, ids}}) do
      0 -> Logger.debug("RuleImplementationLoader: no implementations changed")
      1 -> Logger.info("RuleImplementationLoader: put 1 implementation")
      n -> Logger.info("RuleImplementationLoader: put #{n} implementations")
    end
  end

  defp do_refresh do
    case clean_implementations() do
      :error -> Logger.warn("RuleImplementationLoader: error reading keys from cache")
      0 -> Logger.debug("RuleImplementationLoader: no stale implementations in cache")
      n -> Logger.info("RuleImplementationLoader: deleted #{n} stale implementations from cache")
    end

    case cache_implementations() do
      0 -> Logger.debug("RuleImplementationLoader: no implementations changed")
      1 -> Logger.info("RuleImplementationLoader: put 1 implementation")
      n -> Logger.info("RuleImplementationLoader: put #{n} implementations")
    end
  end

  defp clean_implementations do
    ids =
      Implementations.list_implementations()
      |> Enum.map(&Integer.to_string(&1.id))
      |> MapSet.new()

    case ImplementationCache.keys() do
      {:ok, keys} ->
        keys
        |> MapSet.new(&String.replace_leading(&1, "implementation:", ""))
        |> MapSet.difference(ids)
        |> Enum.map(&ImplementationCache.delete/1)
        |> Enum.count()

      _ ->
        :error
    end
  end

  defp cache_implementations(%{} = params \\ %{}) do
    params
    |> Implementations.list_implementations()
    |> Enum.map(&Map.put(&1, :structure_ids, Implementations.get_structure_ids(&1)))
    |> Enum.map(&ImplementationCache.put/1)
    |> Enum.reject(&(&1 == {:ok, []}))
    |> Enum.count()
  end

  @spec do_deprecate :: :ok
  def do_deprecate do
    with res <- Implementations.deprecate_implementations(),
         {:ok, %{deprecated: {n, _}}} when n > 0 <- res do
      Logger.info("Deprecated #{n} implementations")
    else
      :ok -> :ok
      {:ok, %{deprecated: {0, _}}} -> :ok
      {:error, op, _, _} -> Logger.warn("Failed to deprecate implementations #{op}")
    end
  end
end
