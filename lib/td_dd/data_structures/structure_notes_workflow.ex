defmodule TdDd.DataStructures.StructureNotesWorkflow do
  @moduledoc """
  Workflow module for structure note
  """
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.StructureNote

  def create(%DataStructure{id: data_structure_id} = data_structure, params) do
    latest_note = get_latest_structure_note(data_structure_id)

    structure_note_params =
      params
      |> Map.put("status", "draft")
      |> Map.put("version", next_version(latest_note))
      |> Map.put("df_content", draft_df_content(latest_note, params))

    case can_create_new_draft(latest_note) do
      :ok -> DataStructures.create_structure_note(data_structure, structure_note_params)
      error -> {:error, error}
    end
  end

  def update(%StructureNote{status: from_status} = structure_note, %{"status" => desired_status}) do
    case {from_status, String.to_atom(desired_status)} do
      {:draft, :pending_approval} -> send_for_approval(structure_note)
      {:draft, :published} -> publish(structure_note)
      {:pending_approval, :published} -> publish(structure_note)
      {:pending_approval, :rejected} -> reject(structure_note)
      {:rejected, :draft} -> dereject(structure_note)
      {:published, :deprecated} -> deprecate(structure_note)
      _ -> {:error, :invalid_transition}
    end
  end

  def update(
        %StructureNote{status: :draft} = structure_note,
        %{"df_content" => df_content} = attrs
      ) do
    case attrs do
      %{"status" => "draft"} -> update_content(structure_note, df_content)
      %{"status" => _other_status} -> {:error, :only_draft_are_editable}
      _ -> update_content(structure_note, df_content)
    end
  end

  def update(_structure_note, _attrs) do
    {:error, :unknown_error}
  end

  def delete(%StructureNote{status: status} = structure_note) do
    case status do
      :rejected -> DataStructures.delete_structure_note(structure_note)
      :draft -> DataStructures.delete_structure_note(structure_note)
      _ -> {:error, :undeletable_status}
    end
  end

  # Lifecycle actions for structure notes
  defp update_content(structure_note, df_content) do
    DataStructures.update_structure_note(structure_note, %{"df_content" => df_content})
  end

  defp send_for_approval(structure_note) do
    DataStructures.update_structure_note(structure_note, %{"status" => :pending_approval})
  end

  defp publish(structure_note) do
    case get_latest_structure_note(structure_note.data_structure_id, :published) do
      %StructureNote{} = previous_published ->
        DataStructures.update_structure_note(previous_published, %{"status" => "versioned"})
        DataStructures.update_structure_note(structure_note, %{"status" => "published"})

      nil ->
        DataStructures.update_structure_note(structure_note, %{"status" => "published"})
    end
  end

  defp reject(structure_note) do
    DataStructures.update_structure_note(structure_note, %{"status" => "rejected"})
  end

  defp dereject(structure_note) do
    DataStructures.update_structure_note(structure_note, %{"status" => "draft"})
  end

  defp deprecate(
         %StructureNote{version: version, data_structure_id: data_structure_id} = structure_note
       ) do
    get_latest_structure_note(data_structure_id)
    %{version: latest_version} = get_latest_structure_note(data_structure_id)

    case latest_version do
      ^version ->
        DataStructures.update_structure_note(structure_note, %{"status" => "deprecated"})

      _ ->
        {:error, :a_new_version_exists}
    end
  end

  # Workflow utilities
  defp get_latest_structure_note(data_structure_id, status) do
    data_structure_id
    |> DataStructures.list_structure_notes(status)
    |> Enum.at(-1)
  end

  defp get_latest_structure_note(data_structure_id) do
    data_structure_id
    |> DataStructures.list_structure_notes()
    |> Enum.at(-1)
  end

  defp can_create_new_draft(nil), do: :ok
  defp can_create_new_draft(%{status: :published}), do: :ok
  defp can_create_new_draft(_), do: :conflict

  defp next_version(nil), do: 1
  defp next_version(%{version: version}), do: version + 1

  defp draft_df_content(nil, %{"df_content" => df_content}), do: df_content
  defp draft_df_content(nil, %{}), do: nil
  defp draft_df_content(%{df_content: df_content}, _), do: df_content
end
