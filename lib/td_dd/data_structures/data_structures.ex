defmodule TdDd.DataStructures do
  @moduledoc """
  The DataStructures context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Association.NotLoaded
  alias TdCache.LinkCache
  alias TdCache.StructureCache
  alias TdCache.TemplateCache
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo
  alias TdDd.Utils.CollectionUtils
  alias TdDfLib.Validation

  @search_service Application.get_env(:td_dd, :elasticsearch)[:search_service]

  @doc """
  Returns the list of data_structures.

  ## Examples

      iex> list_data_structures()
      [%DataStructure{}, ...]

  """
  def list_data_structures(params \\ %{}) do
    filter = build_filter(DataStructure, params)

    DataStructure
    |> where([ds], ^filter)
    |> Repo.all()
    |> Repo.preload(:system)
  end

  def list_data_structures_with_no_parents(params \\ %{}, options \\ []) do
    filter = build_filter(DataStructure, params)

    DataStructure
    |> where([ds], ^filter)
    |> where([ds], is_nil(ds.class) or ds.class != "field")
    |> with_deleted(Keyword.get(options, :deleted, true))
    |> Repo.all()
    |> Repo.preload(system: [], versions: :parents)
    |> Enum.filter(&latest_version_is_root?/1)
  end

  defp latest_version_is_root?(%DataStructure{versions: []}), do: false

  defp latest_version_is_root?(%DataStructure{versions: versions}) do
    versions
    |> Enum.max_by(& &1.version)
    |> Map.get(:parents)
    |> Enum.empty?()
  end

  def build_filter(schema, params) do
    params = CollectionUtils.atomize_keys(params)
    fields = schema.__schema__(:fields)
    dynamic = true

    Enum.reduce(Map.keys(params), dynamic, fn key, acc ->
      case Enum.member?(fields, key) do
        true -> add_filter(key, params[key], acc)
        false -> acc
      end
    end)
  end

  defp add_filter(key, value, acc) do
    cond do
      is_list(value) and value == [] ->
        acc

      is_list(value) ->
        dynamic([ds], field(ds, ^key) in ^value and ^acc)

      is_nil(value) ->
        dynamic([ds], is_nil(field(ds, ^key)) and ^acc)

      value ->
        dynamic([ds], field(ds, ^key) == ^value and ^acc)
    end
  end

  @doc """
  Gets a single data_structure.

  Raises `Ecto.NoResultsError` if the Data structure does not exist.

  ## Examples

      iex> get_data_structure!(123)
      %DataStructure{}

      iex> get_data_structure!(456)
      ** (Ecto.NoResultsError)

  """
  def get_data_structure!(id) do
    DataStructure
    |> Repo.get!(id)
    |> Repo.preload(:system)
  end

  def get_data_structure_version!(data_structure_id, version) do
    attrs = %{data_structure_id: data_structure_id, version: version}

    DataStructureVersion
    |> Repo.get_by!(attrs)
    |> Repo.preload(data_structure: :system)
  end

  def get_data_structure_version!(data_structure_version_id) do
    DataStructureVersion
    |> Repo.get!(data_structure_version_id)
    |> Repo.preload(data_structure: :system)
  end

  def get_data_structure_with_fields!(data_structure_id, options \\ []) do
    data_structure_id
    |> get_data_structure!
    |> with_latest_fields(options)
  end

  def get_latest_fields(data_structure_id, options \\ []) do
    data_structure_id
    |> get_latest_version
    |> get_field_structures(options)
  end

  def get_field_structures(data_structure_version, options \\ []) do
    data_structure_version
    |> Ecto.assoc(:children)
    |> join(:inner, [child], ds in assoc(child, :data_structure))
    |> with_deleted(Keyword.get(options, :deleted, true), 4)
    |> where([_child, _parent, _rel, ds], ds.class == "field")
    |> select([_child, _parent, _rel, ds], ds)
    |> Repo.all()
  end

  def get_latest_children(data_structure_id, options \\ []) do
    data_structure_id
    |> get_latest_version
    |> get_children(options)
  end

  def get_children(data_structure_version, options \\ []) do
    data_structure_version
    |> Ecto.assoc([:children, :data_structure])
    |> with_deleted(Keyword.get(options, :deleted, true))
    |> Repo.all()
    |> Repo.preload(:system)
  end

  defp with_deleted(query, true), do: query

  defp with_deleted(query, _deleted) do
    where(query, [ds], is_nil(ds.deleted_at))
  end

  defp with_deleted(query, true, _), do: query

  defp with_deleted(query, _deleted, 4) do
    where(query, [_, _, _, ds], is_nil(ds.deleted_at))
  end

  def get_latest_parents(data_structure_id, options \\ []) do
    data_structure_id
    |> get_latest_version
    |> get_parents(options)
  end

  def get_parents(data_structure_version, options \\ []) do
    data_structure_version
    |> Ecto.assoc([:parents, :data_structure])
    |> with_deleted(Keyword.get(options, :deleted, true))
    |> Repo.all()
    |> Repo.preload(:system)
  end

  defp get_latest_siblings(data_structure_id, options) do
    data_structure_id
    |> get_latest_version
    |> get_siblings(options)
  end

  def get_siblings(data_structure_version, options \\ []) do
    data_structure_version
    |> Ecto.assoc(:parents)
    |> Repo.all()
    |> Enum.filter(&is_active_data_structure_version(&1, Keyword.get(options, :deleted, true)))
    |> Enum.flat_map(&get_children(&1, options))
    |> Enum.uniq()
  end

  defp is_active_data_structure_version(data_structure_version, false) do
    data_structure =
      data_structure_version
      |> Repo.preload(:data_structure)
      |> Map.get(:data_structure)

    is_nil(data_structure.deleted_at)
  end

  defp is_active_data_structure_version(_data_structure_version, _true), do: true

  def get_latest_ancestry(data_structure_id) do
    data_structure_id
    |> get_latest_version
    |> get_ancestry
  end

  def get_versions(%DataStructureVersion{} = dsv) do
    dsv
    |> Ecto.assoc([:data_structure, :versions])
    |> Repo.all()
  end

  def with_versions(%DataStructure{} = data_structure) do
    data_structure
    |> Repo.preload(:versions)
  end

  def with_latest_fields(%{id: id} = data_structure, options \\ []) do
    fields = get_latest_fields(id, options)

    data_structure
    |> Map.put(:data_fields, fields)
  end

  def with_latest_children(%{id: id} = data_structure, options \\ []) do
    children = get_latest_children(id, options)

    data_structure
    |> Map.put(:children, children)
  end

  def with_latest_parents(%{id: id} = data_structure, options \\ []) do
    parents = get_latest_parents(id, options)

    data_structure
    |> Map.put(:parents, parents)
  end

  def with_latest_siblings(%{id: id} = data_structure, options \\ []) do
    siblings = get_latest_siblings(id, options)

    data_structure
    |> Map.put(:siblings, siblings)
  end

  def with_latest_ancestry(%{id: id} = data_structure) do
    ancestry = get_latest_ancestry(id)

    data_structure
    |> Map.put(:ancestry, ancestry)
  end

  @doc """
  Creates a data_structure.

  ## Examples

      iex> create_data_structure(%{field: value})
      {:ok, %DataStructure{}}

      iex> create_data_structure(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_data_structure(attrs \\ %{}) do
    result =
      %DataStructure{}
      |> DataStructure.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, data_structure} ->
        %DataStructureVersion{data_structure_id: data_structure.id, version: 0}
        |> Repo.insert()

        data_structure
        |> with_latest_fields
        |> @search_service.put_search

        {:ok, data_structure |> Repo.preload(:system)}

      _ ->
        result
    end
  end

  @doc """
  Updates a data_structure.

  ## Examples

      iex> update_data_structure(data_structure, %{field: new_value})
      {:ok, %DataStructure{}}

      iex> update_data_structure(data_structure, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_data_structure(
        %DataStructure{type: type} = data_structure,
        %{"df_content" => content} = attrs
      )
      when not is_nil(content) do
    case TemplateCache.get_by_name!(type) do
      %{:content => content_schema} ->
        content_changeset = Validation.build_changeset(content, content_schema)

        case content_changeset.valid? do
          false -> {:error, content_changeset}
          _ -> do_update_data_structure(data_structure, attrs)
        end

      _ ->
        {:error, "Invalid template"}
    end
  end

  def update_data_structure(%DataStructure{} = data_structure, attrs) do
    do_update_data_structure(data_structure, attrs)
  end

  defp do_update_data_structure(%DataStructure{} = data_structure, attrs) do
    result =
      data_structure
      |> DataStructure.update_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, data_structure} ->
        data_structure
        |> with_latest_fields
        |> @search_service.put_search

        result

      _ ->
        result
    end
  end

  @doc """
  Deletes a DataStructure.

  ## Examples

      iex> delete_data_structure(data_structure)
      {:ok, %DataStructure{}}

      iex> delete_data_structure(data_structure)
      {:error, %Ecto.Changeset{}}

  """
  def delete_data_structure(%DataStructure{} = data_structure) do
    result = Repo.delete(data_structure)

    case result do
      {:ok, data_structure} ->
        @search_service.delete_search(data_structure)
        result

      _ ->
        result
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking data_structure changes.

  ## Examples

      iex> change_data_structure(data_structure)
      %Ecto.Changeset{source: %DataStructure{}}

  """
  def change_data_structure(%DataStructure{} = data_structure) do
    DataStructure.changeset(data_structure, %{})
  end

  @doc """
  Returns the latest data structure version for a given data structure id;

  ## Examples

      iex> get_latest_version(1)
      %DataStructureVersion{}

  """
  def get_latest_version(data_structure_id) do
    Repo.one(
      from(dsv in DataStructureVersion,
        where: dsv.data_structure_id == type(^data_structure_id, :integer),
        order_by: [desc: :version],
        limit: 1,
        select: dsv
      )
    )
  end

  def add_domain_id(%{"ou" => domain_name, "domain_id" => nil} = data, domain_map) do
    data |> Map.put("domain_id", Map.get(domain_map, domain_name))
  end

  def add_domain_id(%{"ou" => domain_name, "domain_id" => ""} = data, domain_map) do
    data |> Map.put("domain_id", Map.get(domain_map, domain_name))
  end

  def add_domain_id(%{"ou" => _, "domain_id" => _} = data, _domain_map), do: data

  def add_domain_id(%{"ou" => domain_name} = data, domain_map) do
    data |> Map.put("domain_id", Map.get(domain_map, domain_name))
  end

  def add_domain_id(data, _domain_map), do: data |> Map.put("domain_id", nil)

  def find_data_structure(%{} = clauses) do
    Repo.get_by(DataStructure, clauses)
  end

  def with_field_external_ids(%{data_fields: data_fields} = data_structure) do
    data_structure
    |> Map.put(
      :data_fields,
      Enum.map(
        data_fields,
        &Map.put(
          &1,
          :external_id,
          StructureCache.get_external_id(
            data_structure.system.external_id,
            &1.external_id
          )
        )
      )
    )
  end

  def get_structure_links(structure_id) do
    case LinkCache.list("data_structure", structure_id) do
      {:ok, links} -> links
      _ -> []
    end
  end

  def with_latest_path(%DataStructure{} = data_structure) do
    path =
      data_structure
      |> get_latest_path

    data_structure
    |> Map.put(:path, path)
  end

  def get_latest_path(%DataStructure{id: id}) do
    id
    |> get_latest_version
    |> get_path
  end

  def get_path(%DataStructureVersion{} = dsv) do
    dsv
    |> get_ancestry
    |> Enum.map(& &1.name)
    |> Enum.reverse()
  end

  def get_ancestry(%DataStructureVersion{parents: %NotLoaded{}} = data_structure_version) do
    data_structure_version
    |> Repo.preload([:parents, :data_structure])
    |> get_ancestry
  end

  def get_ancestry(%DataStructureVersion{parents: [], data_structure: data_structure}) do
    [data_structure]
  end

  def get_ancestry(%DataStructureVersion{parents: parents, data_structure: data_structure}) do
    parent =
      case get_first_active_parent(parents) do
        nil -> hd(parents)
        parent -> parent
      end

    [data_structure | get_ancestry(parent)]
  end

  defp get_first_active_parent(parents) do
    parents
    |> Repo.preload(:data_structure)
    |> Enum.find(&(&1.data_structure.deleted_at == nil))
  end

  def get_structure_by_external_ids(system_external_id, external_id) do
    DataStructure
    |> join(:inner, [system], s in assoc(system, :system))
    |> where([_, s], s.external_id == ^system_external_id)
    |> where([d, _], d.external_id == ^external_id)
    |> Repo.one()
  end
end
