defmodule TdDd.DataStructures.StructureNotesWorkflow do
  @moduledoc """
  Workflow module for structure note
  """
  alias TdCluster.Cluster.TdAi
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.StructureNote
  alias TdDd.DataStructures.StructureNotes
  alias TdDd.DataStructures.Validation

  def create_or_update(
        %DataStructure{id: data_structure_id} = data_structure,
        params,
        user_id,
        opts \\ []
      ) do
    latest_note = get_latest_structure_note(data_structure)
    type = DataStructures.get_data_structure_type(data_structure)
    params = Map.put(params, "type", type)

    auto_publish = opts[:auto_publish] == true
    is_bulk_update = opts[:is_bulk_update] == true
    is_strict_update = opts[:is_strict_update] || false

    case require_modification?(data_structure_id, params, is_bulk_update, auto_publish) do
      true ->
        structure_note =
          case latest_note do
            %{status: :draft} ->
              update(latest_note, params, is_strict_update, user_id, type, opts)

            _not_update ->
              bulk_create(data_structure, params, is_strict_update, latest_note, user_id, opts)
          end

        case {structure_note, auto_publish} do
          {{:ok, %StructureNote{} = note_to_publish}, true} ->
            publish(note_to_publish, user_id, opts)

          _ ->
            structure_note
        end

      false ->
        {:ok, latest_note}
    end
  end

  defp bulk_create(data_structure, params, is_strict_update, latest_note, user_id, opts) do
    if can_create_new_draft(latest_note) != :ok,
      do: StructureNotes.delete_structure_note(latest_note, user_id, is_bulk_update: true)

    structure_note_params =
      params
      |> Map.put("status", "draft")
      |> Map.put("version", next_version(latest_note))

    if is_strict_update do
      StructureNotes.create_structure_note(data_structure, structure_note_params, user_id, opts)
    else
      StructureNotes.bulk_create_structure_note(
        data_structure,
        structure_note_params,
        latest_note,
        user_id
      )
    end
  end

  def create(
        %DataStructure{} = data_structure,
        params,
        false = _force_creation,
        user_id
      ),
      do: create(data_structure, params, user_id)

  def create(
        %DataStructure{id: data_structure_id} = data_structure,
        params,
        true = _force_creation,
        user_id
      ) do
    latest_note = get_latest_structure_note(data_structure_id)

    if can_create_new_draft(latest_note) != :ok,
      do: StructureNotes.delete_structure_note(latest_note, user_id)

    create(data_structure, params, user_id)
  end

  def create(
        %DataStructure{id: data_structure_id} = data_structure,
        params,
        user_id
      ) do
    latest_note = get_latest_structure_note(data_structure_id)

    structure_note_params =
      params
      |> Map.put("status", "draft")
      |> Map.put("version", next_version(latest_note))
      |> Map.put("df_content", draft_df_content(latest_note, params))

    case can_create_new_draft(latest_note) do
      :ok ->
        StructureNotes.create_structure_note(data_structure, structure_note_params, user_id)

      error ->
        {:error, error}
    end
  end

  def update(structure_note, attrs, is_strict, user_id, type \\ nil, opts \\ [])

  def update(
        %StructureNote{status: :draft} = structure_note,
        %{"df_content" => df_content} = attrs,
        is_strict,
        user_id,
        type,
        opts
      ) do
    case attrs do
      %{"status" => "draft"} ->
        update_content(structure_note, df_content, user_id, is_strict, type, opts)

      %{"status" => _other_status} ->
        {:error, :only_draft_are_editable}

      _ ->
        update_content(structure_note, df_content, user_id, is_strict, type, opts)
    end
  end

  def update(structure_note, %{"status" => status}, _is_strict, user_id, _type, _opts) do
    case status do
      "pending_approval" -> send_for_approval(structure_note, user_id)
      "published" -> publish(structure_note, user_id)
      "rejected" -> reject(structure_note, user_id)
      "draft" -> unreject(structure_note, user_id)
      "deprecated" -> deprecate(structure_note, user_id)
      _ -> {:error, :invalid_transition}
    end
  end

  def update(%StructureNote{status: _status}, %{"df_content" => _df_content}, _, _, _type, _opts) do
    {:error, :only_draft_are_editable}
  end

  def update(_structure_note, _attrs, _, _, _type, _opts) do
    {:error, :bad_request}
  end

  def delete(%StructureNote{status: status} = structure_note, user_id) do
    case status do
      :rejected ->
        StructureNotes.delete_structure_note(structure_note, user_id)

      :draft ->
        StructureNotes.delete_structure_note(structure_note, user_id)

      _ ->
        {:error, :undeletable_status}
    end
  end

  # Lifecycle actions for structure notes
  defp update_content(structure_note, new_df_content, user_id, true = _is_strict, type, opts) do
    case StructureNotes.update_structure_note(
           structure_note,
           %{"df_content" => new_df_content, "type" => type},
           user_id,
           opts
         ) do
      {:ok, %{structure_note: structure_note}} -> {:ok, structure_note}
      {:error, :structure_note, err, _} -> {:error, err}
      err -> err
    end
  end

  defp update_content(structure_note, new_df_content, user_id, false = _is_strict, type, _opts) do
    StructureNotes.bulk_update_structure_note(
      structure_note,
      %{"df_content" => new_df_content, "type" => type},
      user_id
    )
  end

  defp send_for_approval(structure_note, user_id),
    do: simple_transition(structure_note, :pending_approval, user_id)

  defp reject(structure_note, user_id), do: simple_transition(structure_note, :rejected, user_id)
  defp unreject(structure_note, user_id), do: simple_transition(structure_note, :draft, user_id)

  defp publish(structure_note, user_id, opts \\ []) do
    with {:ok, _} <- can_transit_to(structure_note, :published) do
      case get_latest_structure_note(structure_note.data_structure_id, :published) do
        %StructureNote{} = previous_published ->
          transit_to(previous_published, "versioned", user_id, opts)
          transit_to(structure_note, "published", user_id, opts)

        nil ->
          transit_to(structure_note, "published", user_id, opts)
      end
    end
  end

  defp deprecate(
         %StructureNote{version: version, data_structure_id: data_structure_id} = structure_note,
         user_id
       ) do
    with {:ok, _} <- can_transit_to(structure_note, :deprecated) do
      %{version: latest_version} = get_latest_structure_note(data_structure_id)

      if latest_version == version do
        transit_to(structure_note, "deprecated", user_id)
      else
        {:error, :a_new_version_exists}
      end
    end
  end

  defp simple_transition(structure_note, status, user_id) do
    with {:ok, _} <- can_transit_to(structure_note, status) do
      transit_to(structure_note, Atom.to_string(status), user_id)
    end
  end

  defp transit_to(structure_note, status, user_id, opts \\ []) do
    case StructureNotes.update_structure_note(
           structure_note,
           %{"status" => status},
           user_id,
           opts
         ) do
      {:ok, %{structure_note_update: structure_note_update}} -> {:ok, structure_note_update}
      {:error, :structure_note_update, err, _} -> {:error, err}
      err -> err
    end
  end

  defp can_transit_to(structure_note, status) do
    case status in available_actions(structure_note) do
      true -> {:ok, status}
      false -> {:error, :invalid_transition}
    end
  end

  def available_actions(%DataStructure{id: id} = data_structure) do
    latest = get_latest_structure_note(id)

    draft_status =
      case can_create_new_draft(latest) do
        :ok -> [:draft]
        _ -> []
      end

    ai_suggestion_status =
      case has_ai_suggestion(latest, data_structure) do
        :ok -> [:ai_suggestions]
        _ -> []
      end

    draft_status ++ ai_suggestion_status
  end

  def available_actions(%StructureNote{
        status: status,
        data_structure_id: data_structure_id,
        id: id
      }) do
    %{id: latest_id} = get_latest_structure_note(data_structure_id)
    available_actions(status, latest_id, id)
  end

  def available_actions(:draft, _latest_id, _id),
    do: [:pending_approval, :published, :deleted, :edited, :ai_suggestions]

  def available_actions(:pending_approval, _latest_id, _id), do: [:published, :rejected]
  def available_actions(:rejected, _latest_id, _id), do: [:draft, :deleted]
  def available_actions(:published, latest_id, id) when latest_id == id, do: [:deprecated]
  def available_actions(_status, _latest_id, _id), do: []

  # Workflow utilities
  defp get_latest_structure_note(data_structure_id, status) do
    StructureNotes.get_latest_structure_note(data_structure_id, status)
  end

  defp get_latest_structure_note(%DataStructure{id: id, latest_note: nil}) do
    get_latest_structure_note(id)
  end

  defp get_latest_structure_note(%DataStructure{latest_note: %StructureNote{} = latest}) do
    latest
  end

  defp get_latest_structure_note(data_structure_id) when is_integer(data_structure_id) do
    StructureNotes.get_latest_structure_note(data_structure_id)
  end

  def get_action_editable_action(%DataStructure{id: id}) do
    id
    |> StructureNotes.get_latest_structure_note()
    |> get_action_editable_action()
  end

  def get_action_editable_action(nil), do: :create

  def get_action_editable_action(%{status: status} = structure_note) do
    case {can_create_new_draft(structure_note), status} do
      {:ok, _status} -> :create
      {:conflict, :draft} -> :edit
      _ -> :conflict
    end
  end

  defp can_create_new_draft(nil), do: :ok
  defp can_create_new_draft(%{status: :published}), do: :ok
  defp can_create_new_draft(%{status: :deprecated}), do: :ok
  defp can_create_new_draft(_), do: :conflict

  defp has_ai_suggestion(nil, data_structure), do: valid_ai_suggestion_template(data_structure)

  defp has_ai_suggestion(%{status: :published}, data_structure),
    do: valid_ai_suggestion_template(data_structure)

  defp has_ai_suggestion(%{status: :deprecated}, data_structure),
    do: valid_ai_suggestion_template(data_structure)

  defp has_ai_suggestion(%{status: :draft}, data_structure),
    do: valid_ai_suggestion_template(data_structure)

  defp has_ai_suggestion(_, _), do: :conflict

  defp valid_ai_suggestion_template(
         %{
           current_version: %{type: structure_type},
           system: %{external_id: system_external_id}
         } = data_structure
       ) do
    with true <- Validation.has_ai_suggestion(data_structure),
         {:ok, true} <-
           TdAi.available_resource_mapping(
             "data_structure",
             %{
               "type" => structure_type,
               "system_external_id" => system_external_id
             }
           ) do
      :ok
    else
      _ -> :conflict
    end
  end

  defp valid_ai_suggestion_template(_), do: :conflict

  defp next_version(nil), do: 1
  defp next_version(%{version: version}), do: version + 1

  defp draft_df_content(_, %{"df_content" => df_content}), do: df_content
  defp draft_df_content(nil, %{}), do: nil
  defp draft_df_content(%{df_content: df_content}, _), do: df_content

  defp require_modification?(data_structure_id, params, is_bulk_update, auto_publish) do
    case {get_latest_structure_note(data_structure_id, :published), params} do
      {%{df_content: df_content}, %{"df_content" => raw_params_df_content}} ->
        latest_content = Map.take(df_content, Map.keys(raw_params_df_content))

        case {is_bulk_update, auto_publish, latest_content} do
          {true, true, ^raw_params_df_content} -> false
          _ -> true
        end

      _ ->
        true
    end
  end
end
