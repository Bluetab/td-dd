defmodule TdDd.Canada.UnitAbilities do
  @moduledoc """
  Canada permissions model for Unit resources
  """
  alias TdDd.Accounts.User
  alias TdDd.Lineage.Units.{Node, Unit}
  alias TdDd.Permissions

  def can?(_user, :view_lineage, %Unit{domain_id: nil}) do
    true
  end

  def can?(%User{} = user, :view_lineage, %Unit{domain_id: domain_id}) do
    Permissions.authorized?(user, :view_lineage, domain_id)
  end

  def can?(%User{} = user, :view_lineage, %Node{units: [_ | _] = units}) do
    Enum.any?(units, &can?(user, :view_lineage, &1))
  end

  def can?(_user, :view_lineage, %Node{}) do
    true
  end

  def can?(_user, _action, _entity), do: false
end
