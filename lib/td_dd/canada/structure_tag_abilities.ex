defmodule TdDd.Canada.StructureTagAbilities do
  @moduledoc false
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.Tags.StructureTag
  alias TdDd.Permissions

  # Admin accounts can do anything with data structure tags
  def can?(%Claims{role: "admin"}, _action, _resource), do: true

  def can?(%Claims{} = claims, :mutation, mutation)
      when mutation in [:tag_structure, :delete_structure_tag] do
    Permissions.authorized?(claims, :link_data_structure_tag)
  end

  def can?(%Claims{} = claims, :delete, %StructureTag{data_structure: %{domain_ids: domain_ids}}) do
    Permissions.authorized?(claims, :link_data_structure_tag, domain_ids)
  end

  def can?(%Claims{}, _action, _resource), do: false
end
