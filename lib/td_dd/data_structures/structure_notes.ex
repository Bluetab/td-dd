defmodule TdDd.DataStructures.StructureNotes do
  @moduledoc """
  The DataStructuresNotes context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker

  @doc """
  Returns the list of structure_notes.

  ## Examples

      iex> list_structure_notes()
      [%StructureNote{}, ...]

  """
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

  defp add_params({filter, updated_at}, query) when filter in ["since", "updated_at"],
    do: where(query, [sn], sn.updated_at >= ^updated_at)

  defp add_params({"system_id", system_id}, query) do
    query
    |> join(:inner, [sn], ds in assoc(sn, :data_structure))
    |> where([_sn, ds], ds.system_id == ^system_id)
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

  @doc """
  Gets a single structure_note.

  Raises `Ecto.NoResultsError` if the Structure note does not exist.

  ## Examples

      iex> get_structure_note!(123)
      %StructureNote{}

      iex> get_structure_note!(456)
      ** (Ecto.NoResultsError)

  """
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
    |> Repo.one()
  end

  def get_latest_structure_note(data_structure_id) do
    StructureNote
    |> latest_structure_note_query(data_structure_id)
    |> Repo.one()
    |> Repo.preload(:data_structure)
  end

  @doc """
  Creates a structure_note.

  ## Examples

      iex> create_structure_note(%{field: value}, %{}, user_id)
      {:ok, %StructureNote{}}

      iex> create_structure_note(%{field: bad_value}, %{}, user_id)
      {:error, %Ecto.Changeset{}}

  """
  def create_structure_note(%DataStructure{id: id} = data_structure, attrs, user_id) do
    changeset =
      StructureNote.create_changeset(
        %StructureNote{},
        data_structure |> Map.put(:latest_note, get_latest_structure_note(id)),
        attrs
      )

    Multi.new()
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

  @spec bulk_create_structure_note(
          map,
          :invalid | %{optional(:__struct__) => none, optional(atom | binary) => any},
          nil | %{:data_structure => any, :df_content => any, optional(any) => any},
          any
        ) :: any
  def bulk_create_structure_note(data_structure, attrs, nil, user_id) do
    bulk_create_structure_note(data_structure, attrs, %StructureNote{}, user_id)
  end

  def bulk_create_structure_note(data_structure, attrs, latest_note, user_id) do
    changeset =
      StructureNote.bulk_create_changeset(
        latest_note,
        data_structure,
        attrs
      )

    Multi.new()
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

  @doc """
  Updates a structure_note with bulk_update behaviour.

  ## Examples

      iex> bulk_update_structure_note(structure_note, %{field: new_value}, user_id)
      {:ok, %StructureNote{}}

      iex> bulk_update_structure_note(structure_note, %{field: bad_value}, user_id)
      {:error, %Ecto.Changeset{}}

  """

  def bulk_update_structure_note(%StructureNote{} = structure_note, attrs, user_id) do
    structure_note = Repo.preload(structure_note, :data_structure)
    changeset = StructureNote.bulk_update_changeset(structure_note, attrs)

    if changeset.changes == %{} do
      {:ok, structure_note}
    else
      Multi.new()
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

  @doc """
  Updates a structure_note.

  ## Examples

      iex> update_structure_note(structure_note, %{field: new_value}, user_id)
      {:ok, %StructureNote{}}

      iex> update_structure_note(structure_note, %{field: bad_value}, user_id)
      {:error, %Ecto.Changeset{}}

  """

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
    changeset = StructureNote.changeset(structure_note, attrs)

    %{data_structure: data_structure} =
      structure_note =
      structure_note
      |> Repo.preload(:data_structure)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path])}
    end)
    |> Multi.run(:structure_note, fn _, _ ->
      {:ok, structure_note}
    end)
    |> Multi.update(:structure_note_update, changeset)
    |> Multi.run(:audit, Audit, :structure_note_status_updated, [status, user_id])
    |> Repo.transaction()
    |> case do
      {:ok, res} -> {:ok, Map.get(res, :structure_note_update)}
      {:error, :structure_note_update, err, _} -> {:error, err}
      err -> err
    end
    |> on_update(opts)
  end

  def update_structure_note(%StructureNote{} = structure_note, attrs, user_id, opts) do
    structure_note = Repo.preload(structure_note, :data_structure)
    changeset = StructureNote.changeset(structure_note, attrs)

    Multi.new()
    |> Multi.update(:structure_note, changeset)
    |> Multi.run(:audit, Audit, :structure_note_updated, [changeset, user_id])
    |> Repo.transaction()
    |> case do
      {:ok, res} -> {:ok, Map.get(res, :structure_note)}
      {:error, :structure_note, err, _} -> {:error, err}
      err -> err
    end
    |> on_update(opts)
  end

  @doc """
  Deletes a structure_note.

  ## Examples

      iex> delete_structure_note(structure_note, user_id)
      {:ok, %StructureNote{}}

      iex> delete_structure_note(structure_note, user_id)
      {:error, %Ecto.Changeset{}}

  """
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
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking structure_note changes.

  ## Examples

      iex> change_structure_note(structure_note)
      %Ecto.Changeset{data: %StructureNote{}}

  """
  def change_structure_note(%StructureNote{} = structure_note, attrs \\ %{}) do
    StructureNote.changeset(structure_note, attrs)
  end

  defp on_update(res, opts \\ []) do
    case opts[:is_bulk_update] == true do
      false -> on_update_structure(res)
      _ -> res
    end
  end

  defp on_update_structure({:ok, %StructureNote{status: :published, data_structure_id: id}} = res) do
    IndexWorker.reindex(id)
    res
  end

  defp on_update_structure({:ok, %StructureNote{}} = res), do: res

  defp on_update_structure({:ok, %{} = res}) do
    with %{data_structure: %{id: id}} <- res do
      IndexWorker.reindex(id)
    end

    {:ok, res}
  end

  defp on_update_structure(res), do: res
end
