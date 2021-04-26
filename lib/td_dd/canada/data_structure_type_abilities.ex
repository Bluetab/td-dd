defmodule TdDd.Canada.DataStructureTypeAbilities do
  @moduledoc false
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.DataStructureType

  # Admin accounts can do anything with data structure types
  def can?(%Claims{role: "admin"}, _action, _resource), do: true

  def can?(%Claims{}, :index, %DataStructureType{}), do: true

  def can?(%Claims{}, :index, DataStructureType), do: true

  def can?(%Claims{}, _action, %DataStructureType{}), do: false

  def can?(%Claims{}, _action, DataStructureType), do: false
end
