defmodule TdDd.XLSX.StructureNotes.BulkLoad do
  @moduledoc """
  XLSX Bulk Load Data Structures Notes

  This module provides functionality to process XLSX data for data structures notes bulk operations.
  """

  alias TdCore.Search.IndexWorker
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureTypes
  alias TdDd.DataStructures.StructureNotes
  alias TdDd.DataStructures.StructureNotesWorkflow
  alias TdDd.DataStructures.Validation
  alias TdDfLib.Content
  alias Truedat.XLSX.BulkLoadProtocol

  defimpl BulkLoadProtocol, for: TdDd.DataStructures.StructureNote do
    alias TdDd.XLSX.StructureNotes.BulkLoad

    @required_headers [
      "external_id"
    ]
    @extra_headers []
    @discarded_headers [
      "name",
      "tech_name",
      "alias_name",
      "link_to_structure",
      "domain",
      "type",
      "system",
      "path"
    ]
    def get_opts(_) do
      [
        required_headers: @required_headers,
        extra_headers: @extra_headers,
        discarded_headers: @discarded_headers
      ]
    end

    def bulk_load_item(_scope, data_structure, ctx) do
      BulkLoad.upsert_structure_note(data_structure, ctx)
    end

    def on_complete(_structure_note, ids) do
      IndexWorker.reindex(:structure_notes, Enum.uniq(ids))
    end

    def sheets_to_templates(_impl_for, sheets) do
      DataStructureTypes.list_data_structure_types()
      |> Enum.map(fn %{name: name, template: template} -> {name, template} end)
      |> Enum.filter(fn {name, _} -> name in sheets end)
      |> Map.new()
    end
  end

  def upsert_structure_note(structure_note, ctx) do
    external_id = Map.get(structure_note, "external_id")

    with {:data_structure, %TdDd.DataStructures.DataStructure{} = data_structure} <-
           {:data_structure, check_data_structure(external_id)},
         {:template, %{} = template} <-
           {:template, Map.get(ctx.templates, Map.get(structure_note, "_sheet"))},
         {:permission, true} <- {:permission, check_permission(ctx.claims, data_structure)},
         {:status, status} <- {:status, determine_status(ctx.claims, data_structure, ctx)},
         {:version, {version, was_draft, existing_note}} when is_integer(version) <-
           {:version, determine_version_and_cleanup(data_structure, status, ctx.claims.user_id)},
         {:content, {merged_content, empty_fields}} <-
           {:content,
            prepare_and_merge_content(
              structure_note,
              template,
              existing_note
            )},
         {:validation, :ok} <-
           {:validation, validate_content_fields(merged_content, data_structure, structure_note)},
         {:unchanged, false} <-
           {:unchanged, content_unchanged?(merged_content, existing_note, status)} do
      if was_draft && existing_note do
        StructureNotes.delete_structure_note(existing_note, ctx.claims.user_id,
          is_bulk_update: true
        )
      end

      cleaned_existing_note =
        if existing_note && empty_fields != [] do
          cleaned_df_content = Map.drop(existing_note.df_content || %{}, empty_fields)
          %{existing_note | df_content: cleaned_df_content}
        else
          existing_note
        end

      structure_note_with_params =
        structure_note
        |> Map.put("status", status)
        |> Map.put("version", version)
        |> Map.put("df_content", merged_content)

      changes = compute_update_changes(merged_content, existing_note, status)

      create_structure_note_and_respond(
        StructureNotes.bulk_create_structure_note(
          data_structure,
          structure_note_with_params,
          cleaned_existing_note,
          ctx.claims.user_id
        ),
        data_structure,
        external_id,
        was_draft,
        changes
      )
    else
      {:data_structure, nil} ->
        {:error, {"data_structure_not_found", %{external_id: external_id}}}

      {:template, nil} ->
        {:error,
         {"template_not_found",
          details_with_structure_id(external_id, %{external_id: external_id})}}

      {:permission, false} ->
        {:error,
         {"unauthorized", details_with_structure_id(external_id, %{external_id: external_id})}}

      {:status, :unauthorized} ->
        {:error,
         {"unauthorized", details_with_structure_id(external_id, %{external_id: external_id})}}

      {:version, {:error, {:unreject_failed, reason}}} ->
        {:error,
         {"unreject_failed",
          details_with_structure_id(external_id, %{external_id: external_id, reason: reason})}}

      {:version, {:error, {:pending_approval_conflict, message}}} ->
        {:error,
         {"pending_approval_conflict",
          details_with_structure_id(external_id, %{external_id: external_id, message: message})}}

      {:unchanged, true} ->
        details =
          case check_data_structure(external_id) do
            %TdDd.DataStructures.DataStructure{id: id} ->
              %{external_id: external_id, data_structure_id: id}

            _ ->
              %{external_id: external_id}
          end

        {:unchanged, details}

      {:validation, {:error, errors}} ->
        {:error,
         {"field_validation_error",
          details_with_structure_id(external_id, %{external_id: external_id, errors: errors})}}

      _ ->
        {:error,
         {"unprocessable_entity",
          details_with_structure_id(external_id, %{external_id: external_id})}}
    end
  end

  defp check_data_structure(external_id) do
    DataStructures.get_data_structure_by_external_id(external_id)
  end

  defp details_with_structure_id(external_id, base_map) do
    case check_data_structure(external_id) do
      %TdDd.DataStructures.DataStructure{id: id} ->
        Map.put(base_map, :data_structure_id, id)

      _ ->
        base_map
    end
  end

  defp check_permission(claims, data_structure) do
    can_create_or_edit_draft?(claims, data_structure) or
      Bodyguard.permit?(StructureNotes, :publish_draft, claims, data_structure)
  end

  defp determine_status(claims, data_structure, ctx) do
    to_status = Map.get(ctx, :to_status, "draft")

    case to_status do
      "published" -> determine_published_status(claims, data_structure)
      _ -> determine_draft_status(claims, data_structure)
    end
  end

  defp determine_published_status(claims, data_structure) do
    if Bodyguard.permit?(StructureNotes, :publish_draft, claims, data_structure) do
      "published"
    else
      determine_draft_status(claims, data_structure)
    end
  end

  defp determine_draft_status(claims, data_structure) do
    if can_create_or_edit_draft?(claims, data_structure) do
      "draft"
    else
      :unauthorized
    end
  end

  defp can_create_or_edit_draft?(claims, data_structure) do
    Bodyguard.permit?(StructureNotes, :create, claims, data_structure) or
      Bodyguard.permit?(StructureNotes, :edit, claims, data_structure)
  end

  defp compute_update_changes(merged_content, existing_note, status) do
    existing_content = get_existing_content_for_merge(existing_note) || %{}

    df_content_changes =
      merged_content
      |> Enum.reject(fn {key, new_val} ->
        existing_val = Map.get(existing_content, key)
        field_equal?(new_val, existing_val)
      end)
      |> Map.new()

    changes = %{status: status}

    if df_content_changes != %{} do
      Map.put(changes, :df_content, df_content_changes)
    else
      changes
    end
  end

  defp field_equal?(a, b), do: normalize_value(a) == normalize_value(b)

  defp create_structure_note_and_respond(
         result,
         data_structure,
         external_id,
         was_draft,
         changes
       ) do
    case result do
      {:ok, %{id: id}} ->
        details =
          %{
            id: id,
            external_id: external_id,
            data_structure_id: data_structure.id
          }
          |> Map.put(:changes, changes)

        if was_draft do
          {:updated, {id, details}}
        else
          {:created, {id, details}}
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = extract_changeset_errors(changeset)

        {:error,
         {"structure_note_creation_error",
          %{external_id: external_id, data_structure_id: data_structure.id, errors: errors}}}

      {:error, reason} ->
        {:error,
         {"structure_note_creation_error",
          %{external_id: external_id, data_structure_id: data_structure.id, reason: reason}}}

      error ->
        {:error,
         {"structure_note_creation_error",
          %{external_id: external_id, data_structure_id: data_structure.id, error: error}}}
    end
  end

  defp extract_changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, fn message ->
        %{field: to_string(field), message: message}
      end)
    end)
  end

  defp determine_version_and_cleanup(data_structure, _status, user_id) do
    latest_note = StructureNotes.get_latest_structure_note(data_structure.id)

    case latest_note do
      nil ->
        {1, false, nil}

      %{status: :draft} = draft_note ->
        # Don't delete yet - we need to compare content first
        # The draft will be deleted later if content changed
        {draft_note.version, true, draft_note}

      # TODO: Pending approval handling
      # When a structure note is in pending_approval status and new content is uploaded,
      # we need to decide the appropriate action:
      # - Option 1: Delete the pending_approval note and create a new draft
      # - Option 2: Keep the pending_approval note and handle the conflict
      # - Option 3: Cancel/reject the pending_approval and create new draft
      # This needs to be discussed and implemented based on business requirements.
      %{status: :pending_approval} = _pending_note ->
        {:error,
         {:pending_approval_conflict, "Cannot upload new content when note is pending approval"}}

      %{status: :rejected} = rejected_note ->
        handle_rejected_note(rejected_note, user_id)

      %{status: :published} = published_note ->
        {next_version(published_note), false, published_note}

      %{status: :deprecated} = deprecated_note ->
        {next_version(deprecated_note), false, deprecated_note}

      _ ->
        {next_version(latest_note), false, latest_note}
    end
  end

  defp handle_rejected_note(rejected_note, user_id) do
    case StructureNotesWorkflow.update(rejected_note, %{"status" => "draft"}, false, user_id) do
      {:ok, unrejected_note} ->
        {unrejected_note.version, true, unrejected_note}

      {:error, reason} ->
        {:error, {:unreject_failed, reason}}

      error ->
        {:error, {:unreject_failed, error}}
    end
  end

  defp next_version(nil), do: 1
  defp next_version(%{version: version}), do: version + 1

  defp prepare_and_merge_content(structure_note, template, existing_note) do
    new_content = Map.get(structure_note, "df_content", %{}) || %{}

    field_names = Enum.map(template.content_schema, &Map.get(&1, "name"))

    {filtered_content, empty_fields} = filter_and_normalize_content(new_content, field_names)

    existing_content = get_existing_content_for_merge(existing_note)

    cleaned_existing =
      if empty_fields != [] and existing_content do
        Map.drop(existing_content, empty_fields)
      else
        existing_content
      end

    base_content = cleaned_existing || %{}
    merged = Content.merge(filtered_content, base_content)

    cleaned_merged = Map.drop(merged, empty_fields)

    {cleaned_merged, empty_fields}
  end

  defp filter_and_normalize_content(new_content, field_names) do
    {content, empty_fields} =
      new_content
      |> Map.take(field_names)
      |> Enum.reduce({%{}, []}, fn {key, value}, {acc, empty} ->
        case normalize_field_value(value) do
          nil -> {acc, [key | empty]}
          normalized_value -> {Map.put(acc, key, normalized_value), empty}
        end
      end)

    {content, empty_fields}
  end

  defp normalize_field_value(%{"value" => val, "origin" => _}) when val == "" or val == nil,
    do: nil

  defp normalize_field_value(%{"value" => _, "origin" => _} = value), do: value

  defp normalize_field_value(value) when is_map(value), do: Map.put(value, "origin", "file")

  defp normalize_field_value(value) when value == "" or value == nil, do: nil

  defp normalize_field_value(value), do: %{"value" => value, "origin" => "file"}

  defp validate_content_fields(merged_content, data_structure, _structure_note) do
    fields = Map.keys(merged_content)

    case Validation.validator(data_structure, merged_content, fields) do
      {:error, error} ->
        {:error, [%{field: nil, message: "invalid_template", reason: error}]}

      %{valid?: false, errors: errors} = changeset when errors != [] ->
        {:error, extract_changeset_errors(changeset)}

      _ ->
        :ok
    end
  end

  defp get_existing_content_for_merge(nil), do: nil

  defp get_existing_content_for_merge(%{status: :draft, df_content: df_content}),
    do: df_content

  defp get_existing_content_for_merge(%{status: :published, df_content: df_content}),
    do: df_content

  defp get_existing_content_for_merge(_), do: nil

  defp content_unchanged?(new_content, existing_note, status) do
    case existing_note do
      nil ->
        new_content == %{}

      %{status: :draft, df_content: existing_content} when status == "draft" ->
        maps_equal?(new_content, existing_content)

      %{status: :published, df_content: existing_content} when status == "published" ->
        maps_equal?(new_content, existing_content)

      _ ->
        false
    end
  end

  defp maps_equal?(map1, map2) when is_map(map1) and is_map(map2) do
    normalize_map(map1) == normalize_map(map2)
  end

  defp maps_equal?(_map1, _map2), do: false

  defp normalize_map(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {to_string(k), normalize_value(v)} end)
    |> Enum.sort()
    |> Map.new()
  end

  defp normalize_value(v) when is_map(v) do
    case Map.get(v, "value") do
      nil ->
        v
        |> Map.drop(["origin"])
        |> normalize_map()

      value ->
        normalize_value(value)
    end
  end

  defp normalize_value(v) when is_list(v), do: Enum.map(v, &normalize_value/1)
  defp normalize_value(v), do: v
end
