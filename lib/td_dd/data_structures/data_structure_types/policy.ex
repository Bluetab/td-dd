defmodule TdDd.DataStructures.DataStructureTypes.Policy do
  @moduledoc "Authorization rules for data structure types"

  @behaviour Bodyguard.Policy

  def authorize(_action, %{role: "admin"}, _params), do: true
  def authorize(:index, _claims, _params), do: true
  def authorize(_action, _claims, _params), do: false
end
