defmodule TdDq.Executions.Audit do
  @moduledoc """
  The Executions Audit context. The public functions in this module are designed to
  be called using `Ecto.Multi.run/5`, although the first argument (`repo`) is
  not currently used.
  """

  import TdDq.Audit.AuditSupport, only: [publish: 5]

  @doc """
  Publishes an `:execution_group_created` event. Should be called using `Ecto.Multi.run/5`.
  """
  def execution_group_created(_repo, %{group: group}, %{changes: changes} = _changeset) do
    execution_group_created(group, changes)
  end

  defp execution_group_created(%{id: id, executions: executions} = _group, %{} = changes) do
    user_id = Map.get(changes, :created_by_id, 0)

    executions = Enum.map(executions, &Map.take(&1, [:id, :implementation_id]))

    payload =
      changes
      |> Map.take([:filters])
      |> Map.put(:executions, executions)

    publish("execution_group_created", "execution_group", id, user_id, payload)
  end

  defp execution_group_created(_, _), do: {:error, :invalid}
end
