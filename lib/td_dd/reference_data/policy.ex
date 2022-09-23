defmodule TdDd.ReferenceData.Policy do
  @moduledoc "Authorization rules for reference data"

  alias TdDq.Canada.ImplementationAbilities
  alias TdDq.Implementations.Implementation

  @behaviour Bodyguard.Policy

  # Extract claims from Absinthe Resolution context
  def authorize(action, %{context: %{claims: claims}} = _resolution, params) do
    authorize(action, claims, params)
  end

  def authorize(action, %{role: "user"} = claims, _params) when action in [:list, :show] do
    ImplementationAbilities.can?(claims, "create", Implementation)
  end

  def authorize(action, %{role: "service"}, _params) when action in [:list, :show], do: true

  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(_action, _claims, _params), do: false
end
