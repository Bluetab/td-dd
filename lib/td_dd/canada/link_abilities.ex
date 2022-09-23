defmodule TdDd.Canada.LinkAbilities do
  @moduledoc """
  Canada permissions model for Link resources
  """
  alias TdDd.Permissions

  # Admin accounts can do anything with links
  def can?(%{role: "admin"}, _action, _resource), do: true

  def can?(_claims, :create_link, %{domain_ids: nil}), do: false
  def can?(_claims, :create_link, %{domain_ids: []}), do: false

  def can?(%{} = claims, :create_link, %{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :link_data_structure, domain_ids)
  end
end
