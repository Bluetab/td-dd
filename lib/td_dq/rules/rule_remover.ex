defmodule TdDq.Rules.RuleRemover do
  @moduledoc """
  Provides functionality for archiving rules associated with deleted or
  deprecated business concepts.
  """

  alias TdCache.ConceptCache
  alias TdDq.Rules

  require Logger

  ## Client API

  @doc """
  Perform soft deletion of rules associated with deleted or deprecated
  business concepts.
  """
  def archive_inactive_rules do
    case ConceptCache.active_ids() do
      {:ok, []} -> :ok
      {:ok, active_ids} -> soft_deletion(active_ids)
      _ -> :ok
    end
  end

  ## Private functions

  defp soft_deletion([]), do: :ok

  defp soft_deletion(active_ids) do
    {:ok, %{rules: {rule_count, _}, deprecated: {impl_count, _}}} =
      Rules.soft_deletion(active_ids)

    if rule_count > 0, do: Logger.info("Soft deleted #{rule_count} rules")
    if impl_count > 0, do: Logger.info("Soft deleted #{impl_count} rule implementations")
    :ok
  end
end
