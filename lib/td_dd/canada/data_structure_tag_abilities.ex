defmodule TdDd.Canada.DataStructureTagAbilities do
  @moduledoc false
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.DataStructureTag
  alias TdDd.Permissions

  # Admin accounts can do anything with data structure tags
  def can?(%Claims{role: "admin"}, _action, _resource), do: true

  def can?(%Claims{} = claims, :index, DataStructureTag) do
    Permissions.authorized?(claims, :view_data_structure)
  end

  def can?(%Claims{}, _action, %DataStructureTag{}), do: false

  def can?(%Claims{}, _action, DataStructureTag), do: false
end
