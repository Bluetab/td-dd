defmodule TdDd.DataStructures.BulkUpdate do
  @moduledoc """
  Support for bulk update of data structures.
  """

  alias Codepagex
  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.Search.Indexer
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
      rows
      |> parse_rows(@data_structure_preloads)
      |> Enum.filter(fn {_row, data_structure, _index} -> data_structure end)
      |> Enum.reduce_while([], fn {row, data_structure, index}, acc ->
        case format_content(row, data_structure, index, lang) do
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
  end

  defp parse_rows(rows, preloads \\ []) do
    rows
    |> Enum.with_index(2)
    |> Enum.map(fn
      {%{"external_id" => external_id} = row, index} ->
        {
          row,
          DataStructures.get_data_structure_by_external_id(
            external_id,
            preloads
          ),
          index
        }

      {row, index} ->
        {row, nil, index}
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

  def do_csv_bulk_update(rows, user_id), do: do_csv_bulk_update(rows, user_id, false)

  def do_csv_bulk_update(rows, user_id, auto_publish) do
    Multi.new()
    |> Multi.run(:update_notes, &csv_bulk_update_notes(&1, &2, rows, user_id, auto_publish))
    |> Multi.run(:updates, &csv_bulk_update(&1, &2, rows, user_id))
    |> Multi.run(:audit, &audit(&1, &2, user_id))
    |> Repo.transaction()
    |> on_complete()
  end

  defp csv_bulk_update(_repo, _changes_so_far, rows, user_id) do
    rows
    |> Enum.map(fn {content, %{data_structure: data_structure, row_index: row_index}} ->
      {DataStructure.changeset(data_structure, content, user_id), row_index}
    end)
    |> Enum.reject(fn {changeset, _row_index} -> changeset.changes == %{} end)
    |> Enum.reduce_while(%{}, &reduce_changesets/2)
    |> case do
      %{} = res -> {:ok, res}
      error -> error
    end
  end

  defp csv_bulk_update_notes(_repo, _changes_so_far, rows, user_id, auto_publish) do
    rows
    |> Enum.map(fn {content, %{data_structure: data_structure, row_index: row_index}} ->
      {update_structure_notes(data_structure, content, user_id, auto_publish), row_index}
    end)
    |> Enum.reduce_while(%{}, &csv_reduce_notes_results/2)
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
        {_row, nil, index} ->
          {index, {:error, {:structure, :not_exist}}}

        {%{"domain_external_ids" => domain_external_ids}, %DataStructure{} = structure, index} ->
          domains =
            domain_external_ids
            |> String.split("|", trim: true)
            |> Enum.map(&String.trim(&1))
            |> Enum.map(&TaxonomyCache.get_by_external_id(&1))

          if Enum.any?(domains, &is_nil(&1)) do
            {index, {:error, {:domain, :not_exist}}}
          else
            params = %{domain_ids: Enum.map(domains, & &1.id)}
            changeset = DataStructures.update_changeset(claims, structure, params)

            if Bodyguard.permit?(DataStructures, :update_data_structure, claims, changeset) do
              {index, check_data_structure(changeset)}
            else
              {index, {:error, {:update_domain, :forbidden}}}
            end
          end
      end)
      |> Enum.reduce([[], [], []], fn row, [changesets, ignored, errors] ->
        case row do
          {_index, %Changeset{}} -> [[row | changesets], ignored, errors]
          {_index, {:ok, _}} -> [changesets, [row | ignored], errors]
          _ -> [changesets, ignored, [row | errors]]
        end
      end)

    results = DataStructures.update_data_structures(claims, changesets, false)

    [updated, errored] =
      Enum.reduce(results, [[], []], fn result, [updated, errored] ->
        case result do
          {_index, {:ok, _}} ->
            [[result | updated], errored]

          {index, {:error, _, changeset, _}} ->
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

  defp format_content(row, data_structure, row_index, lang) do
    data_structure
    |> DataStructures.template_name()
    |> Templates.content_schema()
    |> case do
      {:error, error} ->
        {:error, error}

      content_schema ->
        template_fields = Enum.filter(content_schema, &(Map.get(&1, "type") != "table"))
        field_names = Enum.map(template_fields, &Map.get(&1, "name"))

        domain_ids = data_structure.domain_ids
        content = Map.take(row, field_names)
        fields = Map.keys(content)
        content_schema = Enum.filter(template_fields, &(Map.get(&1, "name") in fields))

        content =
          Parser.format_content(%{
            content: content,
            content_schema: content_schema,
            domain_ids: domain_ids,
            lang: lang
          })

        {%{"df_content" => content}, %{data_structure: data_structure, row_index: row_index}}
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

  defp update_structure_notes(data_structure, params, user_id, auto_publish) do
    opts = [auto_publish: auto_publish, is_bulk_update: true]

    case StructureNotesWorkflow.create_or_update(data_structure, params, user_id, opts) do
      {:ok, structure_note} -> {:ok, structure_note}
      error -> {error, data_structure}
    end
  end

  defp csv_reduce_notes_results({result, row_index}, acc) do
    case result do
      {:ok, %{data_structure_id: id} = structure_note} ->
        {:cont, Map.put(acc, id, structure_note)}

      {{:error, error}, %{id: id} = data_structure} ->
        {:cont, Map.put(acc, id, {:error, {error, Map.put(data_structure, :row, row_index)}})}
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

  defp reduce_changesets({%{} = changeset, row_index}, %{} = acc) do
    case Repo.update(changeset) do
      {:ok, %{id: id}} ->
        {:cont, Map.put(acc, id, changeset)}

      {:error, changeset} ->
        {:halt, {:error, Changeset.put_change(changeset, :row, row_index)}}
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
