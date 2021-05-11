defmodule TdDd.Canada.SystemAbilities do
  @moduledoc false
  alias TdDd.Auth.Claims

  # Admin accounts can do anything with systems and their classifiers
  def can?(%Claims{role: "admin"}, _action, _resource), do: true

  # Any authenticated user can view systems and their classifiers
  def can?(%Claims{}, :show, _resource), do: true

  # Non-admin users can only view systems and their classifiers
  def can?(_claims, _action, _resource), do: false
end
