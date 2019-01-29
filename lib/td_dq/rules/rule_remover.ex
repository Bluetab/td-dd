defmodule TdDq.Rules.RuleRemover do
  @moduledoc """
  This Module will be used to perform a soft removement of those rules which 
  business concept has been deleted or deprecated
  """
  use GenServer

  alias TdDq.Rules
  alias TdPerms.BusinessConceptCache

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
    bcs_to_delete = BusinessConceptCache.get_deprecated_business_concept_set()
    bcs_to_avoid_deletion = BusinessConceptCache.get_existing_business_concept_set() -- bcs_to_delete

    Rules.soft_deletion(bcs_to_delete, bcs_to_avoid_deletion)

    schedule_work()
    {:noreply, state}
  end
end
