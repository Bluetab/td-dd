defmodule TdDd.Canada.DataStructureTypeAbilities do
  @moduledoc false
  alias TdDd.DataStructures.DataStructureType

  # Admin accounts can do anything with data structure types
  def can?(%{role: "admin"}, _action, _resource), do: true

  def can?(%{}, :index, %DataStructureType{}), do: true
  def can?(%{}, :index, DataStructureType), do: true

  def can?(%{}, _action, _resource), do: false
end
