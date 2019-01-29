defmodule TdDq.RuleLoader do
  @moduledoc """
  GenServer to load rules counts into Redis
  """

  use GenServer

  alias Ecto.Adapters.SQL
  alias TdDq.Repo
  alias TdPerms.BusinessConceptCache

  require Logger

  @cache_rules_on_startup Application.get_env(:td_dq, :cache_rules_on_startup)

  @count_query """
    select business_concept_id as concept_id, count(*) as count
    from rules group by business_concept_id
  """

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  @impl true
  def init(state) do
    if @cache_rules_on_startup, do: schedule_work(:load_cache, 0)
    {:ok, state}
  end

  @impl true
  def handle_info(:load_cache, state) do
    load_counts()

    {:noreply, state}
  end

  defp schedule_work(action, seconds) do
    Process.send_after(self(), action, seconds)
  end

  defp put_count(business_concept_id, count) do
    BusinessConceptCache.put_field_values(business_concept_id, rule_count: count)
  end

  defp load_counts do
    Repo
    |> SQL.query!(@count_query)
    |> Map.get(:rows)
    |> Enum.filter(fn [bc_id, _] ->
      not is_nil(bc_id) && BusinessConceptCache.exists_bc_in_cache?(bc_id)
    end)
    |> load_counts
  end

  def load_counts(counts) do
    results =
      counts
      |> Enum.map(&put_count(Enum.at(&1, 0), Enum.at(&1, 1)))
      |> Enum.map(fn {res, _} -> res end)

    if Enum.any?(results, &(&1 != :ok)) do
      Logger.warn("Cache loading failed")
    else
      Logger.info("Cached #{length(results)} concept rules counts")
    end
  end
end
