defmodule TdDd.DataStructures.StructureNotes.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures"

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  def authorize(:bulk_upload, %{role: "user"} = claims, _params) do
    Permissions.authorized?(claims, [:create_structure_note, :edit_structure_note])
  end

  def authorize(:auto_publish, %{role: "user"} = claims, _params) do
    Permissions.authorized?(claims, :publish_structure_note_from_draft)
  end

  def authorize(action, %{role: "user"} = claims, %DataStructure{domain_ids: domain_ids} = ds)
      when action in [
             :create_structure_note,
             :delete_structure_note,
             :deprecate_structure_note,
             :edit_structure_note,
             :publish_structure_note,
             :publish_structure_note_from_draft,
             :reject_structure_note,
             :send_structure_note_to_approval,
             :unreject_structure_note,
             :view_structure_note_history
           ] do
    Bodyguard.permit?(DataStructures, :view_data_structure, claims, ds) and
      Permissions.authorized?(claims, _permission = action, domain_ids)
  end

  def authorize(_action, %{role: role}, _params), do: role in ["admin", "service"]
end
