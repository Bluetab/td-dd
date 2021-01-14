defmodule TdDd.Canada.DataStructureTypeAbilities do
  @moduledoc false
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.DataStructureType

  def can?(%Claims{}, :index, %DataStructureType{}), do: true

  def can?(%Claims{}, :index, DataStructureType), do: true

  def can?(%Claims{}, _action, %DataStructureType{}), do: false

  def can?(%Claims{}, _action, DataStructureType), do: false
end
