defmodule TdDd.Canada.ReferenceDataAbilities do
  @moduledoc """
  Permissions for reference datasets
  """

  alias TdDd.Auth.Claims

  def can?(%Claims{role: "admin"}, _action, _resource), do: true

  # Service accounts can do anything with reference data
  def can?(%Claims{role: "service"}, action, _resource) when action in [:show, :list], do: true

  def can?(_claims, _action, _resource), do: false
end
