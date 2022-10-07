defmodule TdDd.UserSearchFilters.Policy do
  @moduledoc "Authorization rules for UserSearchFilters"

  @behaviour Bodyguard.Policy

  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(:create, _, %{"is_global" => true}), do: false
  def authorize(:create, _, _), do: true

  def authorize(_action, _claims, _params), do: false
end
