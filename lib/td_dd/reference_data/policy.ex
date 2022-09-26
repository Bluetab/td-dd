defmodule TdDd.ReferenceData.Policy do
  @moduledoc "Authorization rules for reference data"

  alias TdDq.Canada.ImplementationAbilities
  alias TdDq.Implementations.Implementation

  @behaviour Bodyguard.Policy

  def authorize(action, %{role: "user"} = claims, _params)
      when action in [:list, :show, :query] do
    ImplementationAbilities.can?(claims, "create", Implementation)
  end

  def authorize(action, %{role: "service"}, _params) when action in [:list, :show, :query],
    do: true

  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(_action, _claims, _params), do: false
end
