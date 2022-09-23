defmodule TdDd.Canada.StructureTagAbilities do
  @moduledoc false
  alias TdDd.DataStructures.Tags.StructureTag
  alias TdDd.Permissions

  # Admin accounts can do anything with data structure tags
  def can?(%{role: "admin"}, _action, _resource), do: true

  def can?(%{} = claims, :mutation, mutation)
      when mutation in [:tag_structure, :delete_structure_tag] do
    Permissions.authorized?(claims, :link_data_structure_tag)
  end

  def can?(%{} = claims, :delete, %StructureTag{data_structure: %{domain_ids: domain_ids}}) do
    Permissions.authorized?(claims, :link_data_structure_tag, domain_ids)
  end

  def can?(_claims, _action, _resource), do: false
end
