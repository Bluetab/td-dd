defmodule TdDd.DataStructures.Labels.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures.Labels"

  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  ## REVIEW TD-5509: Que pasa con el admin??? por que solo se añade el user????
  ## realizar pruebas.
  def authorize(:query, %{role: "user"} = claims, _params) do
    Permissions.authorized?(claims, :link_structure_to_structure)
  end
end
