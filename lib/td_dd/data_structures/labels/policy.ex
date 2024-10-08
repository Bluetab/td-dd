defmodule TdDd.DataStructures.Labels.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures.Labels"

  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  # admin and service accounts can perform any GraphQL query
  def authorize(:query, %{role: "admin"}, _resource), do: true
  def authorize(:query, %{role: "service"}, _resource), do: true

  def authorize(:query, %{} = claims, _params) do
    Permissions.authorized?(claims, :link_structure_to_structure)
  end

  def authorize(:query, _claims, _params), do: false
end
