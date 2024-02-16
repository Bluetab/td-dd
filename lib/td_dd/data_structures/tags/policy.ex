defmodule TdDd.DataStructures.Tags.Policy do
  @moduledoc "Authorization rules for tags"

  alias TdDd.DataStructures.Tags.StructureTag
  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(:query, %{} = claims, _params),
    do: Permissions.authorized?(claims, :view_data_structure)

  def authorize(:mutation, %{} = claims, _params),
    do: Permissions.authorized?(claims, :link_data_structure_tag)

  def authorize(:delete, %{} = claims, %StructureTag{data_structure: %{domain_ids: domain_ids}}) do
    Permissions.authorized?(claims, :link_data_structure_tag, domain_ids)
  end

  def authorize(_action, _claims, _params), do: false
end
