defmodule TdDd.Canada.UnitAbilities do
  @moduledoc """
  Canada permissions model for Unit resources
  """
  alias TdDd.Auth.Claims
  alias TdDd.Lineage.Units.{Node, Unit}
  alias TdDd.Permissions

  # Service accounts can create, replace and view units
  def can?(%Claims{role: "service"}, :create, Unit), do: true
  def can?(%Claims{role: "service"}, :update, Unit), do: true
  def can?(%Claims{role: "service"}, :show, Unit), do: true

  def can?(%Claims{}, _action, Unit), do: false

  def can?(_claims, :view_lineage, %Unit{domain_id: nil}), do: true

  def can?(%Claims{} = claims, :view_lineage, %Unit{domain_id: domain_id}) do
    Permissions.authorized?(claims, :view_lineage, domain_id)
  end

  def can?(%Claims{} = claims, :view_lineage, %Node{units: [_ | _] = units}) do
    Enum.any?(units, &can?(claims, :view_lineage, &1))
  end

  def can?(_claims, :view_lineage, %Node{}) do
    true
  end

  def can?(_claims, _action, _entity), do: false
end
