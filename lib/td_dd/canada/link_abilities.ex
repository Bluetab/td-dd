defmodule TdDd.Canada.LinkAbilities do
  @moduledoc """
  Canada permissions model for Business Concept Link resources
  """
  alias TdDd.Auth.Claims
  alias TdDd.Permissions

  def can?(_, :create_link, %{domain_id: nil}), do: false

  def can?(%Claims{} = claims, :create_link, %{domain_id: domain_id}) do
    Permissions.authorized?(claims, :link_data_structure, domain_id)
  end
end
