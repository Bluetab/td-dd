defmodule TdDd.Canada.LinkAbilities do
  @moduledoc """
  Canada permissions model for Business Concept Link resources
  """
  alias TdDd.Auth.Claims
  alias TdDd.Permissions

  # Admin accounts can do anything with links
  def can?(%Claims{role: "admin"}, _action, _resource), do: true

  def can?(_, :create_link, %{domain_id: nil}), do: false

  def can?(%Claims{} = claims, :create_link, %{domain_id: domain_id}) do
    Permissions.authorized?(claims, :link_data_structure, domain_id)
  end
end
