defmodule TdDd.Canada.TagAbilities do
  @moduledoc false
  alias TdDd.DataStructures.Tags.Tag
  alias TdDd.Permissions

  # Admin accounts can do anything with tags
  def can?(%{role: "admin"}, _action, _resource), do: true

  def can?(%{} = claims, :index, Tag), do: Permissions.authorized?(claims, :view_data_structure)

  def can?(%{}, _action, _resource), do: false
end
