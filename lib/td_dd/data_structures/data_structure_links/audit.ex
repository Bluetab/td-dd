defmodule TdDd.DataStructures.DataStructureLinks.Audit do
  @moduledoc """
  The DataStructureLinks Audit context. The public functions in this module are designed to
  be called using `Ecto.Multi.run/5`, although the first argument (`repo`) is
  not currently used.
  """

  import TdDd.Audit.AuditSupport, only: [publish: 5]

  ## REVIEW TD-5509: El nombre del evento que se ha creado es el system created????
  ## Segun la llamada el evento se llama :data_structure_link_created, pero publica un evento que no es correcto
  ## No se realizado test de los eventos
  ## por que tiene una variable llamada _what y por que siempre se envia el source_id como 1
  ## Data structure ya tiene su propio audit, por que no se ha añadido a ese fichero????

  @doc """
  Publishes a `:system_created` event. Should be called using `Ecto.Multi.run/5`.
  """
  def data_structure_link_created(_repo, _what, %{} = changeset, user_id) do
    publish("system_created", "system", 1, user_id, changeset)
  end
end
