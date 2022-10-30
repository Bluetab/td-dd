defmodule TdDd.DataStructures.DataStructureLinks.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures.DataStructureLinks"

  def authorize(_action, %{role: role}, _params), do: role in ["admin", "service"]
  def authorize(_action, _claims, _params), do: false
end
