defmodule TdDd.DataStructures.BulkUpdate do
  @moduledoc """
  Support for bulk update of data structures.
  """

  import Bodyguard, only: [permit?: 4]

  alias Codepagex
  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.FileBulkUpdateEvents
  alias TdDd.DataStructures.Search.Indexer
  alias TdDd.DataStructures.StructureNotes
  alias TdDd.DataStructures.StructureNotesWorkflow
  alias TdDd.Repo
  alias TdDfLib.Parser
  alias TdDfLib.Templates
  alias Truedat.Auth.Claims

  require Logger

  @data_structure_preloads [:system, current_version: :structure_type]

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  def update_all(
        ids,
        %{"df_content" => content},
        %Claims{user_id: user_id} = claims,
        auto_publish
      ) do
    params = %{"df_content" => content, "last_change_by" => user_id}
    Logger.info("Updating #{length(ids)} data structures...")

    Timer.time(
      fn -> do_update(ids, params, claims, auto_publish) end,
      fn ms, _ -> "Data structures updated in #{ms}ms" end
    )
  end

  def from_csv(nil, _), do: {:error, %{message: :no_csv_uploaded}}

  def from_csv(upload, :simple) do
    case parse_file(upload) do
      {:ok, rows} -> parse_rows(rows)
      {:error, _} = error -> error
    end
  end

  def from_csv(upload, lang), do: from_csv(upload, :default, lang)

  def from_csv(upload, :default, lang) do
    with {:ok, rows} <- parse_file(upload) do
      parse(rows, preload: @data_structure_preloads, lang: lang)
    end
  end

  def parse(rows, opts \\ []) do
    rows
    |> parse_rows(opts)
    |> Enum.filter(fn {_row, data_structure, _row_meta} -> data_structure end)
    |> Enum.reduce_while([], fn {row, data_structure, row_meta}, acc ->
      case format_content(row, data_structure, row_meta, opts[:lang]) do
        {:error, error} -> {:halt, {:error, error}}
        content -> {:cont, acc ++ [content]}
      end
    end)
    |> case do
      [_ | _] = contents -> contents
      [] -> {:error, %{message: :external_id_not_found}}
      {:error, _} = error -> error
    end
  end

  defp parse_rows(rows, opts \\ []) do
    rows
    |> Enum.with_index(2)
    |> Enum.map(fn
      {%{"external_id" => external_id} = row, index} ->
        {
          row,
          DataStructures.get_data_structure_by_external_id(
            external_id,
            opts[:preload] || []
          ),
          %{index: index, sheet: opts[:sheet]}
        }

      {row, index} ->
        {row, nil, %{index: index, sheet: opts[:sheet]}}
    end)
  end

  def check_csv_headers(%{path: path}, headers) do
    [read_headers] =
      path
      |> Path.expand()
      |> File.stream!([:trim_bom])
      |> Stream.map(&recode/1)
      |> Stream.reject(&(String.trim(&1) == ""))
      |> CSV.decode!(separator: ?;)
      |> Enum.take(1)

    case read_headers do
      ^headers ->
        :ok

      _other ->
        headers_joined = Enum.join(headers, ", ")
        {:error, %{message: "invalid_headers, must be: #{headers_joined}"}}
    end
  end

  def parse_file(%{path: path}) do
    parse_file(path)
  end

  def parse_file(path) do
    rows =
      path
      |> Path.expand()
      |> File.stream!([:trim_bom])
      |> Stream.map(&recode/1)
      |> Stream.reject(&(String.trim(&1) == ""))
      |> CSV.decode!(separator: ?;, headers: true)
      |> Enum.to_list()

    {:ok, rows}
  rescue
    _ ->
      {:error, %{message: :invalid_file_format}}
  end

  def split_succeeded_errors(notes) do
    notes
    |> Enum.split_with(fn {_k, v} ->
      case v do
        {:error, _} -> false
        _ -> true
      end
    end)
    |> Tuple.to_list()
    |> Enum.map(fn k ->
      Enum.into(k, %{})
    end)
  end

  defp recode(s) do
    if String.valid?(s) do
      s
    else
      Codepagex.to_string!(s, "VENDORS/MICSFT/WINDOWS/CP1252", Codepagex.use_utf_replacement())
    end
  end

  def file_bulk_update(rows, user_id, opts \\ []) do
    auto_publish = opts[:auto_publish] || false
    is_strict_update = opts[:is_strict_update] || false
    store_events = opts[:store_events] || false
    upload_params = Map.put(opts[:upload_params] || %{}, :user_id, user_id)

    Multi.new()
    |> Multi.run(
      :update_notes,
      &file_bulk_update_notes(&1, &2, rows, user_id, auto_publish, is_strict_update)
    )
    |> Multi.run(:updates, &data_structure_file_bulk_update(&1, &2, rows, user_id))
    |> Multi.run(:audit, &audit(&1, &2, user_id))
    |> store_events(store_events, upload_params, opts[:task_reference])
    |> Repo.transaction()
    |> on_complete()
  end

  defp data_structure_file_bulk_update(_repo, _changes_so_far, rows, user_id) do
    rows
    |> Enum.map(fn {content, %{data_structure: data_structure, row_meta: row_meta}} ->
      {DataStructure.changeset(data_structure, content, user_id), row_meta}
    end)
    |> Enum.reject(fn {changeset, _row_meta} -> changeset.changes == %{} end)
    |> Enum.reduce_while(%{}, &reduce_changesets/2)
    |> case do
      %{} = res -> {:ok, res}
      error -> error
    end
  end

  defp file_bulk_update_notes(
         _repo,
         _changes_so_far,
         rows,
         user_id,
         auto_publish,
         is_strict_update
       ) do
    rows
    |> Enum.map(fn {content, %{data_structure: data_structure, row_meta: row_meta}} ->
      {
        update_structure_notes(data_structure, content, user_id, auto_publish, is_strict_update),
        row_meta
      }
    end)
    |> Enum.reduce_while(%{}, &reduce_file_notes_results/2)
    |> case do
      %{} = res -> {:ok, res}
      error -> error
    end
  end

  defp check_data_structure(%Changeset{} = changeset) do
    case changeset do
      %Changeset{valid?: false} ->
        {:error, changeset}

      %Changeset{changes: %{} = changes} when map_size(changes) == 0 ->
        {:ok, %{}}

      _ ->
        changeset
    end
  end

  def csv_bulk_update_domains(rows, claims) do
    [changesets, _ignored, errors] =
      Enum.map(rows, fn
        {_row, nil, %{index: index}} ->
          {index, {:error, {:structure, :not_exist}}}

        {%{"domain_external_ids" => domain_external_ids}, %DataStructure{} = structure,
         %{index: index}} ->
          domains =
            domain_external_ids
            |> String.split("|", trim: true)
            |> Enum.map(&String.trim(&1))
            |> Enum.map(&TaxonomyCache.get_by_external_id(&1))

          with {:has_nil, false} <- {:has_nil, Enum.any?(domains, &is_nil(&1))},
               params = %{domain_ids: Enum.map(domains, & &1.id)},
               changeset = DataStructures.update_changeset(claims, structure, params),
               {:can, true} <-
                 {:can,
                  Bodyguard.permit?(DataStructures, :update_data_structure, claims, changeset)} do
            {index, check_data_structure(changeset)}
          else
            {:has_nil, _} -> {index, {:error, {:domain, :not_exist}}}
            {:can, _} -> {index, {:error, {:update_domain, :forbidden}}}
          end
      end)
      |> Enum.reduce([[], [], []], fn row, [changesets, ignored, errors] ->
        case row do
          {_row_meta, %Changeset{}} -> [[row | changesets], ignored, errors]
          {_row_meta, {:ok, _}} -> [changesets, [row | ignored], errors]
          _ -> [changesets, ignored, [row | errors]]
        end
      end)

    results = DataStructures.update_data_structures(claims, changesets, false)

    [updated, errored] =
      Enum.reduce(results, [[], []], fn result, [updated, errored] ->
        case result do
          {_row_meta, {:ok, _}} ->
            [[result | updated], errored]

          {%{index: index}, {:error, _, changeset, _}} ->
            [updated, [{index, {:error, changeset}} | errored]]

          _ ->
            [updated, errored]
        end
      end)

    %{
      updated: updated,
      errors:
        errored
        |> Kernel.++(errors)
        |> Enum.sort_by(fn {index, _} -> index end, :asc)
    }
  end

  def reject_rows(
        [{_content, %{data_structure: _}} | _] = contents,
        auto_publish,
        claims = %{}
      )
      when is_list(contents) do
    contents
    |> Enum.reject(fn
      {_content, %{data_structure: nil}} ->
        true

      {_content, %{data_structure: data_structure}} ->
        can_edit =
          case StructureNotesWorkflow.get_action_editable_action(data_structure) do
            :create -> permit?(StructureNotes, :create, claims, data_structure)
            :edit -> permit?(StructureNotes, :edit, claims, data_structure)
            _ -> true
          end

        if auto_publish do
          can_edit and
            permit?(StructureNotes, :publish_draft, claims, data_structure)
        else
          can_edit
        end
    end)
  end

  def reject_rows(contents, auto_publish, %{} = claims) do
    contents
    |> Enum.map(fn {_, data_structure, row_meta} ->
      {%{}, %{data_structure: data_structure, row_meta: row_meta}}
    end)
    |> reject_rows(auto_publish, claims)
  end

  def make_summary(updates, updated_notes, not_updated_notes) do
    errors =
      Enum.flat_map(not_updated_notes, fn {_id, {:error, {error, %{} = ds}}} ->
        error
        |> get_messsage_from_error()
        |> Enum.map(fn ms ->
          ms
          |> Map.put(:row, ds.row.index)
          |> Map.put(:sheet, ds.row.sheet)
          |> Map.put(:external_id, ds.external_id)
        end)
      end)

    %{ids: Enum.uniq(Map.keys(updates) ++ Map.keys(updated_notes)), errors: errors}
  end

  defp format_content(row, data_structure, row_meta, lang) do
    data_structure
    |> DataStructures.template_name()
    |> Templates.content_schema()
    |> case do
      {:error, error} ->
        {:error, error}

      content_schema ->
        field_names = Enum.map(content_schema, &Map.get(&1, "name"))

        content =
          row
          |> Map.take(field_names)
          |> Enum.into(%{}, fn {key, value} -> {key, %{"value" => value, "origin" => "file"}} end)

        content =
          Parser.format_content(%{
            content: content,
            content_schema: content_schema,
            domain_ids: data_structure.domain_ids,
            lang: lang
          })

        {%{"df_content" => content}, %{data_structure: data_structure, row_meta: row_meta}}
    end
  end

  defp do_update(ids, %{} = params, %Claims{user_id: user_id}, auto_publish) do
    data_structures =
      DataStructures.list_data_structures(ids: ids, preload: @data_structure_preloads)

    Multi.new()
    |> Multi.run(
      :update_notes,
      &bulk_update_notes(&1, &2, data_structures, params, user_id, auto_publish)
    )
    |> Repo.transaction()
    |> on_complete()
  end

  defp bulk_update_notes(_repo, _changes_so_far, data_structures, params, user_id, auto_publish) do
    data_structures
    |> Enum.map(&update_structure_notes(&1, params, user_id, auto_publish))
    |> Enum.reduce_while(%{}, &reduce_notes_results/2)
    |> case do
      %{} = res -> {:ok, res}
      error -> error
    end
  end

  defp update_structure_notes(
         data_structure,
         params,
         user_id,
         auto_publish,
         is_strict_update \\ false
       ) do
    opts = [auto_publish: auto_publish, is_bulk_update: true, is_strict_update: is_strict_update]

    case StructureNotesWorkflow.create_or_update(data_structure, params, user_id, opts) do
      {:ok, structure_note} -> {:ok, structure_note}
      error -> {error, data_structure}
    end
  end

  defp reduce_file_notes_results({result, row_meta}, acc) do
    case result do
      {:ok, %{data_structure_id: id} = structure_note} ->
        {:cont, Map.put(acc, id, structure_note)}

      {{:error, error}, %{id: id} = data_structure} ->
        {:cont, Map.put(acc, id, {:error, {error, Map.put(data_structure, :row, row_meta)}})}
    end
  end

  defp reduce_notes_results(result, acc) do
    case result do
      {:ok, %{data_structure_id: id} = structure_note} ->
        {:cont, Map.put(acc, id, structure_note)}

      {{:error, error}, %{id: id} = data_structure} ->
        {:cont, Map.put(acc, id, {:error, {error, data_structure}})}
    end
  end

  defp reduce_changesets({%{} = changeset, row_meta}, %{} = acc) do
    case Repo.update(changeset) do
      {:ok, %{id: id}} ->
        {:cont, Map.put(acc, id, changeset)}

      {:error, changeset} ->
        {:halt, {:error, Changeset.put_change(changeset, :row, row_meta)}}
    end
  end

  defp reduce_changesets(%{} = changeset, %{} = acc) do
    case Repo.update(changeset) do
      {:ok, %{id: id}} -> {:cont, Map.put(acc, id, changeset)}
      error -> {:halt, error}
    end
  end

  defp audit(_repo, %{updates: updates}, user_id) do
    Audit.data_structures_bulk_updated(updates, user_id)
  end

  defp store_events(multi, true, upload_params, task_reference) do
    # TODO: remove me when csv bulk upload is removed as well
    multi
    |> Multi.run(:split_results, fn _repo, %{update_notes: update_notes} ->
      {:ok, split_succeeded_errors(update_notes)}
    end)
    |> Multi.run(:summary, fn _repo,
                              %{
                                split_results: [updated_notes, not_updated_notes],
                                updates: updates
                              } ->
      {:ok, make_summary(updates, updated_notes, not_updated_notes)}
    end)
    |> Multi.run(:success_event, fn _repo, %{summary: summary} ->
      FileBulkUpdateEvents.create_completed(
        summary,
        upload_params.user_id,
        upload_params.hash,
        upload_params.file_name,
        task_reference
      )
    end)
  end

  defp store_events(multi, false, _upload_params, _task_reference), do: multi

  defp get_messsage_from_error(%Ecto.Changeset{errors: errors}) do
    Enum.flat_map(errors, fn
      {k, {_error, nested_errors}} -> get_message_from_nested_errors(k, nested_errors)
      {k, _} -> [%{field: nil, message: "#{k}.default"}]
    end)
  end

  defp get_message_from_nested_errors(k, nested_errors) do
    Enum.map(nested_errors, fn
      {field, {_, [{_, e} | _]}} ->
        %{field: field, message: "#{k}.#{e}"}

      {field, {e, []}} ->
        %{field: field, message: "#{k}.#{e}"}

      {field, {e}} ->
        %{field: field, message: "#{k}.#{e}"}

      {field, e} ->
        %{field: field, message: e}
    end)
  end

  defp on_complete({:ok, %{} = result}) do
    ids =
      result
      |> Map.take([:updates, :update_notes])
      |> Enum.flat_map(fn {_, v} -> Map.keys(v) end)
      |> Enum.uniq()

    Indexer.reindex(ids)

    {:ok, result}
  end

  defp on_complete(errors), do: errors
end
