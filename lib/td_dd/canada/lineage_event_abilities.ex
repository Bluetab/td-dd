defmodule TdDd.Canada.LineageAbilities do
  @moduledoc """
  Canada permissions model for Lineage resources
  """
  alias TdDd.Lineage.LineageEvent
  alias TdDd.Permissions

  # Admin and service accounts can do anything with Lineage
  def can?(%{role: role}, _action, _resource) when role in ["admin", "service"], do: true

  def can?(%{} = claims, :list, LineageEvent), do: Permissions.authorized?(claims, :view_lineage)

  def can?(_claims, _action, _resource), do: false
end
