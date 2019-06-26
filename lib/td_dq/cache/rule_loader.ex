defmodule TdDq.Cache.RuleLoader do
  @moduledoc """
  GenServer to load rule entries into shared cache.
  """

  use GenServer
  alias TdCache.RuleCache
  alias TdDq.Rules

  require Logger

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    unless Application.get_env(:td_dq, :env) == :test do
      Process.send_after(self(), :load, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:load, state) do
    count =
      Rules.list_rules()
      |> Enum.filter(&(not is_nil(&1.business_concept_id)))
      |> Enum.map(&RuleCache.put/1)
      |> Enum.reject(&(&1 == {:ok, []}))
      |> Enum.count()

    case count do
      0 -> Logger.debug("RuleLoader: no rules changed")
      1 -> Logger.info("RuleLoader: put 1 rule")
      n -> Logger.info("RuleLoader: put #{n} rules")
    end

    {:noreply, state}
  end
end
