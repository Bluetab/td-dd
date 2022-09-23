defmodule TdDd.Canada.SystemAbilities do
  @moduledoc false

  # Admin accounts can do anything with systems and their classifiers
  def can?(%{role: "admin"}, _action, _resource), do: true

  # Any authenticated user can view systems and their classifiers
  def can?(%{}, :show, _resource), do: true

  # Non-admin users can only view systems and their classifiers
  def can?(_claims, _action, _resource), do: false
end
