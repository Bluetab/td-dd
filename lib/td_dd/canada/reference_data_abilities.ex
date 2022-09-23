defmodule TdDd.Canada.ReferenceDataAbilities do
  @moduledoc """
  Permissions for reference datasets
  """

  alias TdDq.Canada.ImplementationAbilities
  alias TdDq.Implementations.Implementation

  def can?(%{role: "admin"}, _action, _resource), do: true

  # Service accounts can list and show reference data
  def can?(%{role: "service"}, action, _resource) when action in [:list, :show], do: true

  def can?(%{} = claims, action, _resource) when action in [:list, :show] do
    ImplementationAbilities.can?(claims, "create", Implementation)
  end

  def can?(_claims, _action, _resource), do: false
end
