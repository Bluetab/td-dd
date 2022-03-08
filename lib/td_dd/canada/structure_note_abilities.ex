defmodule TdDd.Canada.StructureNoteAbilities do
  @moduledoc false
  alias TdDd.Auth.Claims
  alias TdDd.Canada.DataStructureAbilities
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Permissions

  def can?(%Claims{role: "admin"}, _action, _domain_id) do
    true
  end

  def can?(%Claims{} = claims, :bulk_upload, StructureNote) do
    Permissions.authorized?(claims, [:create_structure_note, :edit_structure_note])
  end

  def can?(%Claims{} = claims, :auto_publish, StructureNote) do
    Permissions.authorized?(claims, :publish_structure_note_from_draft)
  end

  def can?(%Claims{} = claims, action, %{domain_id: domain_id} = data_structure) do
    DataStructureAbilities.can?(claims, :view_data_structure, data_structure) and
      Permissions.authorized?(claims, action, domain_id)
  end

  def can?(_claims, _action, _domain_id) do
    false
  end
end
