defmodule TdDd.DataStructures.RelationTypes.Policy do
  @moduledoc "Authorization rules for relation types"

  @behaviour Bodyguard.Policy

  def authorize(_action, %{role: "admin"}, _params), do: true
  def authorize(_action, _claims, _params), do: false
end
