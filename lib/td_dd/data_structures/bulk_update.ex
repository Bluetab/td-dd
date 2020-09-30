defmodule TdDd.DataStructures.BulkUpdate do
  @moduledoc """
  Support for bulk update of data structures.
  """

  require Logger

  alias Ecto.Multi
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker
  alias TdDfLib.Format
  alias TdDfLib.Templates

  def update_all(ids, %{"df_content" => content}, %{id: user_id} = user) do
    params = %{"df_content" => content, "last_change_by" => user_id}
    Logger.info("Updating #{length(ids)} data structures...")

    Timer.time(
      fn -> do_update(ids, params, user) end,
      fn ms, _ -> "Data structures updated in #{ms}ms" end
    )
  end

  def from_csv(nil, _user), do: {:error, %{message: :no_csv_uploaded}}

  def from_csv(upload, user) do
    rows =
      upload
      |> Map.get(:path)
      |> Path.expand()
      |> File.stream!()
      |> CSV.decode!(separator: ?;, headers: true)
      |> Enum.to_list()

    external_ids = Enum.map(rows, &Map.get(&1, "external_id"))
    data_structures = DataStructures.list_data_structures(%{external_id: external_ids})

    rows
    |> Enum.with_index()
    |> Enum.map(&prepare_content(&1, data_structures))
    |> do_csv_bulk_update(user.id)
  end

  defp do_csv_bulk_update(rows, user_id) do
    Multi.new()
    |> Multi.run(:updates, &csv_bulk_update(&1, &2, rows))
    |> Multi.run(:audit, &audit(&1, &2, user_id))
    |> Repo.transaction()
    |> on_complete()
  end

  defp csv_bulk_update(_repo, _changes_so_far, rows) do
    rows
    |> Enum.map(fn {content, %{data_structure: data_structure}} ->
      DataStructure.merge_changeset(data_structure, content)
    end)
    |> Enum.reject(&(&1.changes == %{}))
    |> Enum.reduce_while(%{}, &reduce_changesets/2)
    |> case do
      %{} = res -> {:ok, res}
      error -> error
    end
  end

  defp prepare_content({%{"external_id" => external_id} = row, row_index}, data_structures) do
    data_structure = Enum.find(data_structures, &(Map.get(&1, :external_id) == external_id))

    content_schema =
      data_structure
      |> DataStructures.template_name()
      |> Templates.content_schema()

    template_fields = Enum.map(content_schema, & &1["name"])
    content = Map.take(row, template_fields)
    content = format_content(%{content: content, content_schema: content_schema})

    {%{df_content: content}, %{data_structure: data_structure, row_index: row_index}}
  end

  defp format_content(%{content: content, content_schema: content_schema})
       when not is_nil(content) do
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

  defp do_update(ids, %{} = params, %{id: user_id}) do
    Multi.new()
    |> Multi.run(:updates, &bulk_update(&1, &2, ids, params))
    |> Multi.run(:audit, &audit(&1, &2, user_id))
    |> Repo.transaction()
    |> on_complete()
  end

  defp bulk_update(_repo, _changes_so_far, ids, params) do
    [id: {:in, ids}]
    |> DataStructures.list_data_structures()
    |> Enum.filter(&Map.get(&1, :df_content))
    |> Enum.map(&DataStructure.merge_changeset(&1, params))
    |> Enum.reject(&(&1.changes == %{}))
    |> Enum.reduce_while(%{}, &reduce_changesets/2)
    |> case do
      %{} = res -> {:ok, res}
      error -> error
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

  defp on_complete(errors), do: errors
end
