defmodule TdDq.Rules.RuleRemover do
  @moduledoc """
  This Module will be used to perform a soft removement of those rules which 
  business concept has been deleted or deprecated
  """
  use GenServer

  alias TdCache.ConceptCache
  alias TdDq.Rules

  require Logger

  @rule_removement Application.get_env(:td_dq, :rule_removement)
  @rule_removement_frequency Application.get_env(:td_dq, :rule_removement_frequency)

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(state) do
    if @rule_removement, do: schedule_work()
    {:ok, state}
  end

  defp schedule_work do
    Process.send_after(self(), :work, @rule_removement_frequency)
  end

  def handle_info(:work, state) do
    case ConceptCache.active_ids() do
      {:ok, active_ids} -> soft_deletion(active_ids)
      _ -> :ok
    end

    schedule_work()
    {:noreply, state}
  end

  defp soft_deletion([]), do: :ok

  defp soft_deletion(active_ids) do
    {count, _} = Rules.soft_deletion(active_ids)
    if count > 0, do: Logger.info("Soft deleted #{count} rules")
    :ok
  end
end
