defmodule TdDd.Canada.ReferenceDataAbilities do
  @moduledoc """
  Permissions for reference datasets
  """

  alias TdDd.Auth.Claims
  alias TdDq.Canada.ImplementationAbilities
  alias TdDq.Implementations.Implementation

  def can?(%Claims{role: "admin"}, _action, _resource), do: true

  # Service accounts can do anything with reference data
  def can?(%Claims{role: "service"}, action, _resource) when action in [:show, :list], do: true

  def can?(%Claims{} = claims, action, _resource) when action in [:list, :show] do
    ImplementationAbilities.can?(claims, "create", Implementation)
  end

  def can?(_claims, _action, _resource), do: false
end
