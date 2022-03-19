defmodule TdDd.DataStructures.BulkUpdate do
  @moduledoc """
  Support for bulk update of data structures.
  """

  require Logger

  alias Codepagex
  alias Ecto.Changeset
  alias Ecto.Multi
  import Ecto.Query
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.StructureNotesWorkflow
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker
  alias TdDfLib.Format
  alias TdDfLib.Templates

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

  def from_csv_simple(nil), do: {:error, %{message: :no_csv_uploaded}}

  def from_csv_simple(upload) do
    case parse_file(upload) do
      {:ok, rows} ->
        rows
        |> Enum.with_index()
        |> Enum.map(fn {row, index} -> {row, index + 2} end)
        |> Enum.map(fn
          {row, index} ->
            %{
              row: row,
              row_index: index
            }
        end)

      errors ->
        {:error, errors}
    end
  end

  def from_csv(nil), do: {:error, %{message: :no_csv_uploaded}}

  def from_csv(upload) do
    with {:ok, rows} <- parse_file(upload) do
      rows
      |> Enum.with_index()
      |> Enum.map(fn {row, index} -> {row, index + 2} end)
      |> Enum.map(fn
        {%{"external_id" => external_id} = row, index} ->
          {
            row,
            DataStructures.get_data_structure_by_external_id(
              external_id,
              [:system, [current_version: :structure_type]]
            ),
            index
          }

        {row, index} ->
          {row, nil, index}
      end)
      |> Enum.filter(fn {_row, data_structure, _index} -> data_structure end)
      |> Enum.reduce_while([], fn {row, data_structure, index}, acc ->
        case format_content(row, data_structure, index) do
          {:error, error} -> {:halt, {:error, error}}
          content -> {:cont, acc ++ [content]}
        end
      end)
      |> case do
        [_ | _] = contents -> contents
        [] -> {:error, %{message: :external_id_not_found}}
        errors -> {:error, errors}
      end
    end
  end

  def check_csv_headers(%{path: path}, headers) do
    [read_headers] = path
    |> Path.expand()
    |> File.stream!([:trim_bom])
    |> Stream.map(&recode/1)
    |> Stream.reject(&(String.trim(&1) == ""))
    |> CSV.decode!(separator: ?;)
    |> Enum.take(1)
    case read_headers do
      ^headers -> :ok
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

  def csv_bulk_update_domains(rows) do
    ds_external_ids =
      Enum.reduce(
        rows,
        MapSet.new(),
        fn
          %{
            row: %{
              "external_id" => external_id,
              "domain_external_ids" => _domain_external_ids
            },
            row_index: _row_index
          }, acc ->
            MapSet.put(acc, external_id)

          _other, acc ->
            acc
        end
      )

    ds_external_ids_list = MapSet.to_list(ds_external_ids)

    existing_data_structures =
      from(ds in TdDd.DataStructures.DataStructure,
        where: ds.external_id in ^ds_external_ids_list
      )
      |> Repo.all()

    existing_ds_by_id =
      Enum.reduce(
        existing_data_structures,
        %{},
        fn %DataStructure{external_id: external_id} = data_structure, acc ->
          Map.put(acc, external_id, data_structure)
        end
      )

    inexistent_ds_external_ids =
      MapSet.difference(
        ds_external_ids,
        Map.keys(existing_ds_by_id)
        |> MapSet.new()
      )

    rows_existing_ds_external_id =
      Stream.filter(rows, fn
        %{
          row: %{"external_id" => ds_external_id},
          row_index: _row_index
        } ->
          ds_external_id not in inexistent_ds_external_ids

        _ ->
          true
      end)

    {valid_changesets, invalid_changesets} =
      rows_existing_ds_external_id
      |> Stream.map(fn
        %{
          row: %{
            "external_id" => external_id,
            "domain_external_ids" => domain_external_ids
          },
          row_index: row_index
        } ->
          %{
            row_index: row_index,
            external_id: external_id,
            changeset:
              DataStructure.changeset_check_domain_ids(
                existing_ds_by_id[external_id],
                %{external_domain_ids: split(domain_external_ids)},
                1
              )
          }
      end)
      |> Enum.split_with(fn %{changeset: %Ecto.Changeset{} = changeset} -> changeset.valid? end)

    valid_applied_changesets =
      valid_changesets
      |> apply()
      |> Enum.to_list()

    {inserted_count, _result} =
      Repo.insert_all(
        TdDd.DataStructures.DataStructure,
        Enum.map(valid_applied_changesets, &Map.get(&1, :changeset)),
        conflict_target: [:external_id],
        on_conflict: {:replace, [:domain_ids]}
      )

    %{
      inserted_count: inserted_count,
      valid: valid_applied_changesets,
      invalid_changesets: invalid_changesets
    }
  end

  def split(domain_external_ids) do
    String.split(domain_external_ids, "|", trim: true)
    |> Enum.map(&String.trim(&1))
  end

  def existing_domains_by_external_ids(external_domain_ids) do
    Enum.reduce(
      external_domain_ids,
      {[], []},
      fn external_domain_id, {acc_existing, acc_inexisting} ->
        case TdCache.TaxonomyCache.get_by_external_id(external_domain_id) do
          %{id: domain_id} -> {[domain_id | acc_existing], acc_inexisting}
          nil -> {acc_existing, [external_domain_id | acc_inexisting]}
        end
      end
    )
  end

  def apply(valid_item_changesets) do
    valid_item_changesets
    |> Stream.map(fn
      %{
        changeset: %Ecto.Changeset{} = changeset,
        row_index: row_index
      } ->
        %{
          changeset:
            changeset
            |> Ecto.Changeset.apply_changes()
            |> clean(),
          row_index: row_index
        }
    end)
  end

  # turns %Struct{} into a map with only non-nil item values (no association or __meta__ structs)
  def clean(item) do
    item
    |> Map.from_struct()
    # or something similar
    |> Enum.reject(fn
      {_key, nil} ->
        true

      {_key, %{:__struct__ => struct}}
      when struct in [Ecto.Schema.Metadata, Ecto.Association.NotLoaded] ->
        # rejects __meta__: #Ecto.Schema.Metadata<:built, "items">
        # and association: #Ecto.Association.NotLoaded<association :association is not loaded>
        true

      {:external_domain_ids, _external_domain_ids} ->
        true

      _other ->
        false
    end)
    |> Enum.into(%{})
  end

  defp format_content(row, data_structure, row_index) do
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
          format_content(%{
            content: content,
            content_schema: content_schema,
            domain_ids: domain_ids
          })

        {%{"df_content" => content}, %{data_structure: data_structure, row_index: row_index}}
    end
  end

  defp format_content(%{content: content, content_schema: content_schema, domain_ids: domain_ids})
       when not is_nil(content) do
    content = Format.apply_template(content, content_schema, domain_ids: domain_ids)

    content_schema
    |> Enum.filter(fn %{"type" => schema_type, "cardinality" => cardinality} ->
      schema_type in ["url", "enriched_text", "integer", "float"] or
        (schema_type in ["string", "user"] and cardinality in ["*", "+"])
    end)
    |> Enum.filter(fn %{"name" => name} ->
      field_content = Map.get(content, name)
      not is_nil(field_content) and is_binary(field_content) and field_content != ""
    end)
    |> Enum.into(
      content,
      &format_field(&1, content)
    )
  end

  defp format_content(params), do: params

  defp format_field(schema, content) do
    {Map.get(schema, "name"),
     Format.format_field(%{
       "content" => Map.get(content, Map.get(schema, "name")),
       "type" => Map.get(schema, "type"),
       "cardinality" => Map.get(schema, "cardinality"),
       "values" => Map.get(schema, "values")
     })}
  end

  defp do_update(ids, %{} = params, %Claims{user_id: user_id}, auto_publish) do
    data_structures =
      DataStructures.list_data_structures(
        [id: {:in, ids}],
        [:system, [current_version: :structure_type]]
      )

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

  defp on_complete({:ok, %{updates: updates} = result}) do
    updates
    |> Map.keys()
    |> IndexWorker.reindex()

    {:ok, result}
  end

  defp on_complete({:ok, %{update_notes: update_notes} = result}) do
    update_notes
    |> Map.keys()
    |> IndexWorker.reindex()

    {:ok, result}
  end

  defp on_complete(errors), do: errors
end
