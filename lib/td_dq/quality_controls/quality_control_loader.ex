defmodule TdDq.QualityControlLoader do
  @moduledoc """
  GenServer to load quality control counts into Redis
  """

  use GenServer

  alias Ecto.Adapters.SQL
  alias TdDq.Repo
  alias TdPerms.BusinessConceptCache

  require Logger

  @cache_quality_controls_on_startup Application.get_env(:td_dq, :cache_quality_controls_on_startup)

  @count_query """
    select business_concept_id as concept_id, count(*) as count
    from quality_controls group by business_concept_id
  """

  def start_link(name \\ nil) do
    GenServer.start_link(__MODULE__, nil, [name: name])
  end

  @impl true
  def init(state) do
    if @cache_quality_controls_on_startup, do: schedule_work(:load_cache, 0)
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
    BusinessConceptCache.put_field_values(business_concept_id, q_rule_count: count)
  end

  defp load_counts do
    Repo
    |> SQL.query!(@count_query)
    |> Map.get(:rows)
    |> load_counts
  end

  def load_counts(counts) do
    results = counts
    |> Enum.map(&put_count(Enum.at(&1, 0), Enum.at(&1, 1)))
    |> Enum.map(fn {res, _} -> res end)

    if Enum.any?(results, &(&1 != :ok)) do
      Logger.warn("Cache loading failed")
    else
      Logger.info("Cached #{length(results)} concept quality control counts")
    end
  end

end
