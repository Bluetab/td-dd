defmodule TdDd.DataStructures.BulkUpdate.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures.BulkUpdate"

  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  # Admin accounts can do anything with data structures
  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(:bulk_update_domains, %{role: "user"} = claims, _params) do
    Permissions.authorized?(claims, :manage_structures_domain)
  end

  def authorize(_action, _claims, _params), do: false
end
