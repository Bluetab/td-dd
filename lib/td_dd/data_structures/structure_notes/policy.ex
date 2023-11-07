defmodule TdDd.DataStructures.StructureNotes.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures"

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  def authorize(action, %{role: "user"} = claims, %DataStructure{domain_ids: domain_ids} = ds)
      when action in [
             :create,
             :delete,
             :deprecate,
             :edit,
             :publish,
             :publish_draft,
             :reject,
             :submit,
             :unreject,
             :history,
             :ai_suggestions
           ] do
    Bodyguard.permit?(DataStructures, :view_data_structure, claims, ds) and
      Permissions.authorized?(claims, permission(action), domain_ids)
  end

  def authorize(_action, %{role: role}, _params), do: role in ["admin", "service"]

  defp permission(:create), do: :create_structure_note
  defp permission(:delete), do: :delete_structure_note
  defp permission(:deprecate), do: :deprecate_structure_note
  defp permission(:edit), do: :edit_structure_note
  defp permission(:history), do: :view_structure_note_history
  defp permission(:publish), do: :publish_structure_note
  defp permission(:publish_draft), do: :publish_structure_note_from_draft
  defp permission(:reject), do: :reject_structure_note
  defp permission(:submit), do: :send_structure_note_to_approval
  defp permission(:unreject), do: :unreject_structure_note
  defp permission(:ai_suggestions), do: :ai_structure_note
end
