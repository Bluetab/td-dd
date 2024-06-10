defmodule TdDd.DataStructures.StructureNotes do
  @moduledoc """
  The DataStructuresNotes context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.Search.Indexer
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Repo

  defdelegate authorize(action, user, params), to: TdDd.DataStructures.StructureNotes.Policy

  def list_structure_notes do
    Repo.all(StructureNote)
  end

  def list_structure_notes(%{} = params) do
    cursor_params = get_cursor_params(params)

    params
    |> Enum.reduce(StructureNote, &add_params/2)
    |> where_cursor(cursor_params)
    |> page_limit(cursor_params)
    |> order(cursor_params)
    |> Repo.all()
    |> Repo.preload(:data_structure)
  end

  def list_structure_notes(data_structure_id) do
    StructureNote
    |> where(data_structure_id: ^data_structure_id)
    |> order_by(asc: :version)
    |> Repo.all()
  end

  def list_structure_notes(data_structure_id, statuses) when is_list(statuses) do
    StructureNote
    |> where(data_structure_id: ^data_structure_id)
    |> where([sn], sn.status in ^statuses)
    |> order_by(asc: :version)
    |> Repo.all()
  end

  def list_structure_notes(data_structure_id, status),
    do: list_structure_notes(data_structure_id, [status])

  defp add_params({"status", status}, query), do: where(query, status: ^status)

  defp add_params({"statuses", statuses}, query), do: where(query, [sn], sn.status in ^statuses)

  defp add_params({filter, updated_at}, query) when filter in ["since", "updated_at"],
    do: where(query, [sn], sn.updated_at >= ^updated_at)

  defp add_params({filter, updated_at}, query) when filter in ["until"],
    do: where(query, [sn], sn.updated_at <= ^updated_at)

  defp add_params({"system_id", system_id}, query) do
    query
    |> join(:inner, [sn], ds in assoc(sn, :data_structure))
    |> where([_sn, ds], ds.system_id == ^system_id)
  end

  defp add_params({"system_ids", []}, query), do: query

  defp add_params({"system_ids", system_ids}, query) do
    query
    |> join(:inner, [sn], ds in assoc(sn, :data_structure))
    |> where([_sn, ds], ds.system_id in ^system_ids)
  end

  defp add_params({"domain_ids", []}, query), do: query

  defp add_params({"domain_ids", domain_ids}, query) do
    numeric_domain_ids = Enum.map(domain_ids, &String.to_integer(&1))

    query
    |> join(:inner, [sn], ds in assoc(sn, :data_structure))
    |> where([_sn, ds], fragment("? && ?", ds.domain_ids, ^numeric_domain_ids))
  end

  defp add_params(_, query), do: query

  defp where_cursor(query, %{cursor: %{offset: offset}}) when is_integer(offset) do
    offset(query, ^offset)
  end

  defp where_cursor(query, _), do: query

  defp page_limit(query, %{cursor: %{size: size}}) when is_integer(size) do
    limit(query, ^size)
  end

  defp page_limit(query, _), do: query

  defp order(query, cursor_params) do
    case Map.has_key?(cursor_params, :cursor) do
      true -> order_by(query, [sn], asc: sn.updated_at, asc: sn.id)
      false -> query
    end
  end

  defp get_cursor_params(%{"cursor" => %{} = cursor}) do
    offset = Map.get(cursor, "offset")
    size = Map.get(cursor, "size")

    %{cursor: %{offset: offset, size: size}}
  end

  defp get_cursor_params(params), do: params

  def get_structure_note!(id), do: Repo.get!(StructureNote, id)

  def latest_structure_note_query(query, data_structure_id) do
    query
    |> where(data_structure_id: ^data_structure_id)
    |> order_by(desc: :version)
    |> limit(1)
  end

  def get_latest_structure_note(data_structure_id, status) do
    StructureNote
    |> where(status: ^status)
    |> latest_structure_note_query(data_structure_id)
    |> preload(:data_structure)
    |> Repo.one()
  end

  def get_latest_structure_note(data_structure_id) do
    StructureNote
    |> latest_structure_note_query(data_structure_id)
    |> preload(:data_structure)
    |> Repo.one()
  end

  def create_structure_note(%DataStructure{id: id} = data_structure, attrs, user_id) do
    changeset =
      StructureNote.create_changeset(
        %StructureNote{},
        %{data_structure | latest_note: get_latest_structure_note(id)},
        attrs
      )

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path, :parent_relations])}
    end)
    |> Multi.insert(:structure_note, changeset)
    |> Multi.run(:audit, Audit, :structure_note_updated, [changeset, user_id])
    |> Repo.transaction()
    |> case do
      {:ok, res} -> {:ok, Map.get(res, :structure_note)}
      {:error, :structure_note, err, _} -> {:error, err}
      err -> err
    end
    |> on_update()
  end

  def bulk_create_structure_note(data_structure, attrs, nil, user_id) do
    bulk_create_structure_note(
      data_structure,
      attrs,
      %StructureNote{data_structure: data_structure},
      user_id
    )
  end

  def bulk_create_structure_note(data_structure, attrs, latest_note, user_id) do
    changeset =
      StructureNote.bulk_create_changeset(
        latest_note,
        data_structure,
        attrs
      )

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path, :parent_relations])}
    end)
    |> Multi.insert(:structure_note, changeset)
    |> Multi.run(:audit, Audit, :structure_note_updated, [changeset, user_id])
    |> Repo.transaction()
    |> case do
      {:ok, res} -> {:ok, Map.get(res, :structure_note)}
      {:error, :structure_note, err, _} -> {:error, err}
      err -> err
    end
    |> on_update()
  end

  @doc "Updates a structure_note with bulk_update behaviour"
  def bulk_update_structure_note(%StructureNote{} = structure_note, attrs, user_id) do
    %{data_structure: data_structure} =
      structure_note = Repo.preload(structure_note, :data_structure)

    changeset = StructureNote.bulk_update_changeset(structure_note, attrs)

    if changeset.changes == %{} do
      {:ok, structure_note}
    else
      Multi.new()
      |> Multi.run(:latest, fn _, _ ->
        {:ok, DataStructures.get_latest_version(data_structure, [:path, :parent_relations])}
      end)
      |> Multi.update(:structure_note, changeset)
      |> Multi.run(:audit, Audit, :structure_note_updated, [changeset, user_id])
      |> Repo.transaction()
      |> case do
        {:ok, res} -> {:ok, Map.get(res, :structure_note)}
        {:error, :structure_note, err, _} -> {:error, err}
        err -> err
      end
      |> on_update()
    end
  end

  def update_structure_note(_structure_note, _attrs, _user_id, opts \\ [])

  def update_structure_note(
        %StructureNote{} = structure_note,
        %{"status" => status} = attrs,
        user_id,
        opts
      )
      when status in [
             "published",
             "pending_approval",
             "rejected",
             "published",
             "versioned",
             "draft",
             "deprecated"
           ] do
    %{data_structure: data_structure} =
      structure_note = Repo.preload(structure_note, :data_structure)

    changeset = StructureNote.changeset(structure_note, attrs)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path, :parent_relations])}
    end)
    |> Multi.run(:structure_note, fn _, _ -> {:ok, structure_note} end)
    |> Multi.update(:structure_note_update, changeset)
    |> maybe_update_alias(status, user_id)
    |> Multi.run(:audit, Audit, :structure_note_status_updated, [status, user_id])
    |> Repo.transaction()
    |> on_update(opts)
  end

  def update_structure_note(%StructureNote{} = structure_note, attrs, user_id, opts) do
    %{data_structure: data_structure} =
      structure_note = Repo.preload(structure_note, :data_structure)

    changeset = StructureNote.changeset(structure_note, attrs)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path, :parent_relations])}
    end)
    |> Multi.update(:structure_note, changeset)
    |> Multi.run(:audit, Audit, :structure_note_updated, [changeset, user_id])
    |> Repo.transaction()
    |> on_update(opts)
  end

  def maybe_update_alias(multi, "deprecated", user_id) do
    Multi.update(multi, :update_alias, fn %{
                                            structure_note_update: %{
                                              data_structure: data_structure
                                            }
                                          } ->
      DataStructure.alias_changeset(data_structure, nil, user_id)
    end)
  end

  def maybe_update_alias(multi, "published", user_id) do
    Multi.update(multi, :update_alias, fn
      %{structure_note_update: %{data_structure: data_structure, df_content: %{} = content}} ->
        DataStructure.alias_changeset(data_structure, Map.get(content, "alias"), user_id)
    end)
  end

  def maybe_update_alias(multi, _status, _user_id), do: multi

  def delete_structure_note(
        %StructureNote{} = structure_note,
        user_id
      ) do
    %{data_structure: data_structure} =
      structure_note =
      structure_note
      |> Repo.preload(:data_structure)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path])}
    end)
    |> Multi.delete(:structure_note, structure_note)
    |> Multi.run(:audit, Audit, :structure_note_deleted, [user_id])
    |> Repo.transaction()
    |> case do
      {:ok, %{structure_note: structure_note}} ->
        {:ok, structure_note}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
    |> DataStructures.maybe_reindex_grant_requests()
  end

  defp on_update(res, opts \\ []) do
    case opts[:is_bulk_update] == true do
      false -> on_update_structure(res)
      _ -> res
    end
    |> DataStructures.maybe_reindex_grant_requests()
  end

  defp on_update_structure(
         {:ok, %{structure_note_update: %{status: status, data_structure_id: id}}} = res
       )
       when status in [:published, :deprecated] do
    Indexer.reindex(id)

    DataStructures.maybe_reindex_grant_requests(res)
  end

  defp on_update_structure(res), do: res

  def suggestion_fields_for_template(template_id) do
    {:ok, %{content: content}} = TdCache.TemplateCache.get(template_id)

    content
    |> TdDfLib.Format.flatten_content_fields()
    |> Enum.filter(& &1["ai_suggestion"])
    |> Enum.map(&map_suggestion_field/1)
  end

  defp map_suggestion_field(%{"values" => %{"fixed" => possible_values}} = field) do
    field
    |> Map.take(["name", "description"])
    |> Map.put("possible_values", possible_values)
  end

  defp map_suggestion_field(%{"values" => %{"fixed_tuple" => tuples}} = field) do
    possible_values = Enum.map(tuples, & &1["value"])

    field
    |> Map.take(["name", "description"])
    |> Map.put("possible_values", possible_values)
  end

  defp map_suggestion_field(field), do: Map.take(field, ["name", "description"])
end
