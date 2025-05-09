defmodule TdDd.DataStructures.StructureNotes.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures"

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  def authorize(_action, %{role: role}, _params) when role in ["admin", "service"], do: true

  def authorize(action, claims, %DataStructure{domain_ids: domain_ids} = ds)
      when action in [
             :ai_suggestions,
             :create,
             :delete,
             :deprecate,
             :edit,
             :history,
             :publish_draft,
             :publish,
             :reject,
             :submit,
             :unreject
           ] do
    Bodyguard.permit?(DataStructures, :view_data_structure, claims, ds) and
      Permissions.authorized?(claims, permission(action), domain_ids)
  end

  def authorize(_action, _, _params), do: false

  defp permission(:ai_suggestions), do: :ai_structure_note
  defp permission(:create), do: :create_structure_note
  defp permission(:delete), do: :delete_structure_note
  defp permission(:deprecate), do: :deprecate_structure_note
  defp permission(:edit), do: :edit_structure_note
  defp permission(:history), do: :view_structure_note_history
  defp permission(:publish_draft), do: :publish_structure_note_from_draft
  defp permission(:publish), do: :publish_structure_note
  defp permission(:reject), do: :reject_structure_note
  defp permission(:submit), do: :send_structure_note_to_approval
  defp permission(:unreject), do: :unreject_structure_note
end
