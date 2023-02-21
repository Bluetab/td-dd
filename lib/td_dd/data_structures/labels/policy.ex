defmodule TdDd.DataStructures.Labels.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures.Labels"

  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  def authorize(:query, %{role: "user"} = claims, _params) do
    Permissions.authorized?(claims, :link_structure_to_structure)
  end
end
