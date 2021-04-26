defmodule TdDd.Systems.Audit do
  @moduledoc """
  The Systems Audit context. The public functions in this module are designed to
  be called using `Ecto.Multi.run/5`, although the first argument (`repo`) is
  not currently used.
  """

  import TdDd.Audit.AuditSupport, only: [publish: 4, publish: 5]

  @doc """
  Publishes a `:system_created` event. Should be called using `Ecto.Multi.run/5`.
  """
  def system_created(_repo, %{system: %{id: id}}, %{} = changeset, user_id) do
    publish("system_created", "system", id, user_id, changeset)
  end

  @doc """
  Publishes a `:system_updated` event. Should be called using `Ecto.Multi.run/5`.
  """
  def system_updated(_repo, %{system: %{id: id}}, %{} = changeset, user_id) do
    publish("system_updated", "system", id, user_id, changeset)
  end

  @doc """
  Publishes a `:system_deleted` event. Should be called using `Ecto.Multi.run/5`.
  """
  def system_deleted(_repo, %{system: %{id: id}}, user_id) do
    publish("system_deleted", "system", id, user_id)
  end
end
