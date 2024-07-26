defmodule TdDd.Lineage.Policy do
  @moduledoc "Authorization rules for Lineage"

  alias TdDd.Lineage.LineageEvent
  alias TdDd.Lineage.Units.Node
  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  # Admin accounts can do anything with units
  def authorize(_action, %{role: "admin"}, _params), do: true

  # Service accounts can create, replace and view units
  def authorize(:create, %{role: "service"}, _params), do: true
  def authorize(:update, %{role: "service"}, _params), do: true
  def authorize(:view, %{role: "service"}, _params), do: true

  # view_lineage required to view nodes and lineage events
  def authorize(:list, %{} = claims, LineageEvent),
    do: Permissions.authorized?(claims, :view_lineage)

  def authorize(:view_lineage, %{} = claims, %Node{domain_ids: domain_ids = [_ | _]}),
    do: Permissions.authorized?(claims, :view_lineage, domain_ids)

  def authorize(:view_lineage, %{} = claims, %Node{}),
    do: Permissions.authorized?(claims, :view_lineage)

  def authorize(_action, _claims, _params), do: false
end
