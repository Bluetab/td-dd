defmodule TdDd.Executions.Audit do
  @moduledoc """
  The Executions Audit context. The public functions in this module are designed to
  be called using `Ecto.Multi.run/5`, although the first argument (`repo`) is
  not currently used.
  """

  import TdDd.Audit.AuditSupport, only: [publish: 5]

  @doc """
  Publishes an `:execution_group_created` event. Should be called using `Ecto.Multi.run/5`.
  """
  def execution_group_created(_repo, %{profile_group: %{created_by_id: created_by_id} = group}) do
    handle_execution_group_created(group, %{created_by_id: created_by_id})
  end

  def execution_group_created(_repo, %{profile_group: group}, %{changes: changes} = _changeset) do
    handle_execution_group_created(group, changes)
  end

  defp handle_execution_group_created(%{id: id, executions: executions} = _group, %{} = changes) do
    user_id = Map.get(changes, :created_by_id, 0)

    executions = Enum.map(executions, &Map.take(&1, [:id, :data_structure_id]))
    payload = %{executions: executions}
    publish("execution_group_created", "profile_execution_group", id, user_id, payload)
  end

  defp handle_execution_group_created(_, _), do: {:error, :invalid}
end
