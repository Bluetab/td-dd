defmodule TdDd.Canada.LineageAbilities do
  @moduledoc """
  Canada permissions model for Lineage resources
  """
  alias TdDd.Auth.Claims
  alias TdDd.Lineage.LineageEvent
  alias TdDd.Permissions

  # Admin and service accounts can do anything with Lineage
  def can?(%Claims{role: role}, _action, _resource) when role in ["admin", "service"], do: true

  def can?(%Claims{} = claims, :list, LineageEvent) do
    Permissions.authorized?(claims, :view_lineage)
  end

  def can?(_claims, _action, _entity), do: false
end
