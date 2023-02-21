defmodule TdDd.DataStructures.DataStructureLinks.Audit do
  @moduledoc """
  The Systems Audit context. The public functions in this module are designed to
  be called using `Ecto.Multi.run/5`, although the first argument (`repo`) is
  not currently used.
  """

  import TdDd.Audit.AuditSupport, only: [publish: 5]

  @doc """
  Publishes a `:system_created` event. Should be called using `Ecto.Multi.run/5`.
  """
  def data_structure_link_created(_repo, _what, %{} = changeset, user_id) do
    publish("system_created", "system", 1, user_id, changeset)
  end
end
