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

  def update(structure_note, %{"status" => status}) do
    case String.to_atom(status) do
      :pending_approval -> send_for_approval(structure_note)
      :published -> publish(structure_note)
      :rejected -> reject(structure_note)
      :draft -> unreject(structure_note)
      :deprecated -> deprecate(structure_note)
      _ -> {:error, :invalid_transition}
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

  defp send_for_approval(structure_note), do: simple_transition(structure_note, :pending_approval)
  defp reject(structure_note), do: simple_transition(structure_note, :rejected)
  defp unreject(structure_note), do: simple_transition(structure_note, :draft)

  defp publish(structure_note) do
    with {:ok, _} <- structure_note |> can_transit_to(:published) do
      case get_latest_structure_note(structure_note.data_structure_id, :published) do
        %StructureNote{} = previous_published ->
          transit_to(previous_published, "versioned")
          transit_to(structure_note, "published")

        nil ->
          transit_to(structure_note, "published")
      end
    end
  end

  defp deprecate(
         %StructureNote{version: version, data_structure_id: data_structure_id} = structure_note
       ) do
    with {:ok, _} <- structure_note |> can_transit_to(:deprecated) do
      get_latest_structure_note(data_structure_id)
      %{version: latest_version} = get_latest_structure_note(data_structure_id)

      if latest_version == version do
          transit_to(structure_note, "deprecated")
      else
          {:error, :a_new_version_exists}
      end
    end
  end

  defp simple_transition(structure_note, status) do
    with {:ok, _} <- structure_note |> can_transit_to(status) do
      transit_to(structure_note, Atom.to_string(status))
    end
  end

  defp transit_to(structure_note, status) do
    DataStructures.update_structure_note(structure_note, %{"status" => status})
  end

  defp can_transit_to(structure_note, status) do
    case status in available_actions(structure_note) do
      true -> {:ok, status}
      false -> {:error, :invalid_transition}
    end
  end

  def available_actions(%StructureNote{status: status}) do
    case status do
      :draft -> [:pending_approval, :published, :deleted, :edited]
      :pending_approval -> [:published, :rejected]
      :rejected -> [:draft, :deleted]
      :published -> [:deprecated]
      _ -> []
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
