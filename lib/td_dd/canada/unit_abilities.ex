defmodule TdDd.Canada.UnitAbilities do
  @moduledoc """
  Canada permissions model for Unit resources
  """
  alias TdDd.Lineage.Units.Node
  alias TdDd.Lineage.Units.Unit
  alias TdDd.Permissions

  # Admin accounts can do anything with units
  def can?(%{role: "admin"}, _action, _resource), do: true

  # Service accounts can create, replace and view units
  def can?(%{role: "service"}, :create, Unit), do: true
  def can?(%{role: "service"}, :update, Unit), do: true
  def can?(%{role: "service"}, :show, Unit), do: true

  def can?(%{}, _action, Unit), do: false

  def can?(%{} = claims, :view_lineage, %Node{domain_ids: domain_ids = [_ | _]}) do
    Permissions.authorized?(claims, :view_lineage, domain_ids)
  end

  def can?(_claims, :view_lineage, %Node{}), do: true

  def can?(%{} = claims, :view_lineage, %{id: id, hint: :domain}) do
    Permissions.authorized?(claims, :view_lineage, id)
  end

  def can?(%{} = claims, :view_domain, %{id: id, hint: :domain}) do
    Permissions.authorized?(claims, :view_domain, id)
  end

  def can?(_claims, _action, _entity), do: false
end
