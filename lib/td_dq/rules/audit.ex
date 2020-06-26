defmodule TdDq.Rules.Audit do
  @moduledoc """
  The Rules Audit context. The public functions in this module are designed to
  be called using `Ecto.Multi.run/5`, although the first argument (`repo`) is
  not currently used.
  """

  import TdDq.Audit.AuditSupport, only: [publish: 1, publish: 4, publish: 5]

  @doc """
  Publishes a `:rule_created` event. Should be called using `Ecto.Multi.run/5`.
  """
  def rule_created(_repo, %{rule: %{id: id}}, %{} = changeset, user_id) do
    publish("rule_created", "rule", id, user_id, changeset)
  end

  @doc """
  Publishes a `:rule_updated` event. Should be called using `Ecto.Multi.run/5`.
  """
  def rule_updated(_repo, %{rule: %{id: id}}, %{} = changeset, user_id) do
    publish("rule_updated", "rule", id, user_id, changeset)
  end

  @doc """
  Publishes a `:rule_deleted` event. Should be called using `Ecto.Multi.run/5`.
  """
  def rule_deleted(_repo, %{rule: %{id: id}}, user_id) do
    publish("rule_deleted", "rule", id, user_id)
  end

  @doc """
  Publishes `:rule_result_created` events.  Should be called using `Ecto.Multi.run/5`.
  """
  def rule_results_created(_repo, %{results: results}, user_id) do
    results
    |> Enum.map(&rule_result_created(&1, user_id))
    |> publish()
  end

  defp rule_result_created(%{id: id} = payload, user_id) do
    payload =
      payload
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    %{
      event: "rule_result_created",
      resource_type: "rule_result",
      resource_id: id,
      user_id: user_id,
      payload: payload
    }
  end
end
