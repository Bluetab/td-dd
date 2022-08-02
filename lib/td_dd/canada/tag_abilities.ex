defmodule TdDd.Canada.TagAbilities do
  @moduledoc false
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.Tags.Tag
  alias TdDd.Permissions

  # Admin accounts can do anything with tags
  def can?(%Claims{role: "admin"}, _action, _resource), do: true

  def can?(%Claims{} = claims, :index, Tag) do
    Permissions.authorized?(claims, :view_data_structure)
  end

  def can?(%Claims{}, _action, %Tag{}), do: false

  def can?(%Claims{}, _action, Tag), do: false
end
