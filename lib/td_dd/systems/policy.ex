defmodule TdDd.Systems.Policy do
  @moduledoc "Authorization rules for Systems"

  @behaviour Bodyguard.Policy

  # Admin accounts can do anything with systems and their classifiers
  def authorize(_action, %{role: "admin"}, _params), do: true

  # Any authenticated user can view systems and their classifiers
  def authorize(:view, %{}, _params), do: true

  # Non-admin users can only view systems and their classifiers
  def authorize(_action, _claims, _params), do: false
end
