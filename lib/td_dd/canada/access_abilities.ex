defmodule TdDd.Canada.AccessAbilities do
  @moduledoc """
  Canada permissions model for Access resources
  """
  alias TdDd.Auth.Claims

  # Admin and service accounts can do anything with Access
  def can?(%Claims{role: role}, _action, _resource) when role in ["admin", "service"], do: true

  def can?(_claims, _action, _entity), do: false
end
