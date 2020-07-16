defmodule TdDd.Canada.DataStructureTypeAbilities do
  @moduledoc false
  alias TdDd.Accounts.User
  alias TdDd.DataStructures.DataStructureType

  def can?(%User{}, :index , %DataStructureType{}), do: true

  def can?(%User{}, :index , DataStructureType), do: true

  def can?(%User{}, _action, %DataStructureType{}), do: false

  def can?(%User{}, _action, DataStructureType), do: false
end
