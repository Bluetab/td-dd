defmodule TdDd.Canada.UnitAbilities do
  @moduledoc """
  Canada permissions model for Unit resources
  """
  alias TdDd.Auth.Claims
  alias TdDd.Lineage.Units.{Node, Unit}
  alias TdDd.Permissions

  # Admin accounts can do anything with units
  def can?(%Claims{role: "admin"}, _action, _resource), do: true

  # Service accounts can create, replace and view units
  def can?(%Claims{role: "service"}, :create, Unit), do: true
  def can?(%Claims{role: "service"}, :update, Unit), do: true
  def can?(%Claims{role: "service"}, :show, Unit), do: true

  def can?(%Claims{}, _action, Unit), do: false

  def can?(%Claims{} = claims, :view_lineage, %Node{domain_ids: domain_ids = [_ | _]}) do
    Permissions.authorized?(claims, :view_lineage, domain_ids)
  end

  def can?(_claims, :view_lineage, %Node{}) do
    true
  end

  def can?(_claims, _action, _entity), do: false
end
