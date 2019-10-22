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
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Profile
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker
  alias TdDd.Utils.CollectionUtils
  alias TdDfLib.Validation

  @doc """
  Returns the list of data_structures.

  ## Examples

      iex> list_data_structures()
      [%DataStructure{}, ...]

  """
  def list_data_structures(params \\ %{}, options \\ []) do
    filter = build_filter(DataStructure, params)

    DataStructure
    |> preload([ds], [:system])
    |> where([ds], ^filter)
    |> Repo.all()
    |> Enum.map(&enrich(&1, options))
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

  def get_data_structures(ids, preload \\ :system) do
    from(ds in DataStructure, where: ds.id in ^ids, preload: ^preload, select: ds)
    |> Repo.all()
  end

  def get_data_structure_version!(data_structure_id, version, options) do
    attrs = %{data_structure_id: data_structure_id, version: version}

    DataStructureVersion
    |> Repo.get_by!(attrs)
    |> Repo.preload(data_structure: :system)
    |> enrich(options)
  end

  def get_data_structure_version!(data_structure_version_id, options) do
    DataStructureVersion
    |> Repo.get!(data_structure_version_id)
    |> Repo.preload(data_structure: :system)
    |> enrich(options)
  end

  defp enrich(nil = _target, _opts), do: nil

  defp enrich(target, nil = _opts), do: target

  defp enrich(%DataStructure{} = ds, options) do
    ds
    |> enrich(options, :versions, fn ds -> Repo.preload(ds, :versions) end)
    |> enrich(options, :latest, fn ds -> get_latest_version(ds) end)
  end

  defp enrich(%DataStructureVersion{} = dsv, options) do
    deleted = not is_nil(Map.get(dsv, :deleted_at))

    dsv
    |> enrich(options, :parents, fn dsv -> get_parents(dsv, deleted: deleted) end)
    |> enrich(options, :children, fn dsv -> get_children(dsv, deleted: deleted) end)
    |> enrich(options, :siblings, fn dsv -> get_siblings(dsv, deleted: deleted) end)
    |> enrich(options, :data_fields, fn dsv ->
      get_field_structures(dsv,
        deleted: deleted,
        preload: if(Enum.member?(options, :profile), do: [data_structure: :profile], else: [])
      )
    end)
    |> enrich(options, :data_field_external_ids, fn dsv -> get_field_external_ids(dsv) end)
    |> enrich(options, :data_field_links, fn dsv -> get_field_links(dsv) end)
    |> enrich(options, :versions, fn dsv -> get_versions(dsv) end)
    |> enrich(options, :system, fn dsv ->
      dsv |> Repo.preload(data_structure: :system) |> Map.get(:data_structure) |> Map.get(:system)
    end)
    |> enrich(options, :profile, fn dsv -> get_profile(dsv) end)
    |> enrich(options, :ancestry, fn dsv -> get_ancestry(dsv) end)
    |> enrich(options, :path, fn dsv -> get_path(dsv) end)
    |> enrich(options, :links, fn %{data_structure_id: id} -> get_structure_links(id) end)
  end

  defp enrich(%{} = target, options, key, fun) do
    target_key = get_target_key(key)

    case Enum.member?(options, key) do
      false -> target
      true -> Map.put(target, target_key, fun.(target))
    end
  end

  defp get_target_key(:data_field_external_ids), do: :data_fields
  defp get_target_key(:data_field_links), do: :data_fields
  defp get_target_key(key), do: key

  defp get_profile(%DataStructureVersion{} = dsv) do
    dsv
    |> Repo.preload(data_structure: :profile)
    |> Map.get(:data_structure)
    |> Map.get(:profile)
  end

  def get_field_structures(data_structure_version, options \\ []) do
    data_structure_version
    |> Ecto.assoc(:children)
    |> where([child, _parent, _rel], child.class == "field")
    |> with_deleted(options, dynamic([child, _parent, _rel], is_nil(child.deleted_at)))
    |> select([child, _parent, _rel], child)
    |> Repo.all()
    |> Repo.preload(options[:preload] || [])
  end

  def get_children(%DataStructureVersion{id: id}, options \\ []) do
    DataStructureRelation
    |> where([r], r.parent_id == ^id)
    |> join(:inner, [r], parent in assoc(r, :child))
    |> with_deleted(options, dynamic([_, parent], is_nil(parent.deleted_at)))
    |> order_by([_, child], asc: child.data_structure_id, desc: child.version)
    |> select([_, child], child)
    |> distinct(true)
    |> Repo.all()
    |> Enum.uniq_by(& &1.data_structure_id)
    |> Repo.preload(data_structure: :system)
  end

  def get_parents(%DataStructureVersion{id: id}, options \\ []) do
    DataStructureRelation
    |> where([r], r.child_id == ^id)
    |> join(:inner, [r], parent in assoc(r, :parent))
    |> with_deleted(options, dynamic([_, parent], is_nil(parent.deleted_at)))
    |> order_by([_, parent], asc: parent.data_structure_id, desc: parent.version)
    |> select([_, parent], parent)
    |> distinct(true)
    |> Repo.all()
    |> Enum.uniq_by(& &1.data_structure_id)
    |> Repo.preload(data_structure: :system)
  end

  def get_siblings(%DataStructureVersion{id: id}, options \\ []) do
    DataStructureRelation
    |> where([r], r.child_id == ^id)
    |> join(:inner, [r], parent in assoc(r, :parent))
    |> join(:inner, [_, parent], child in assoc(parent, :children))
    |> with_deleted(options, dynamic([_, parent, _], is_nil(parent.deleted_at)))
    |> with_deleted(options, dynamic([_, _, child], is_nil(child.deleted_at)))
    |> order_by([_, _, sibling], asc: sibling.data_structure_id, desc: sibling.version)
    |> select([_, _, sibling], sibling)
    |> distinct(true)
    |> Repo.all()
    |> Enum.uniq_by(& &1.data_structure_id)
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

  @doc """
  Creates a data_structure.

  ## Examples

      iex> create_data_structure(%{field: value})
      {:ok, %DataStructure{}}

      iex> create_data_structure(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_data_structure(attrs \\ %{}) do
    {dsv_attrs, ds_attrs} =
      Map.split(attrs, ["class", "description", "metadata", "group", "name", "type", "version"])

    Repo.transaction(fn ->
      with {:ok, data_structure} <- insert_data_structure(ds_attrs),
           {:ok, _dsv} <- insert_data_structure_version(data_structure, dsv_attrs) do
        IndexWorker.reindex(data_structure.id)
        Repo.preload(data_structure, :system)
      else
        {:error, e} -> Repo.rollback(e)
        e -> Repo.rollback(e)
      end
    end)
  end

  defp insert_data_structure(attrs) do
    %DataStructure{}
    |> DataStructure.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_data_structure_version(%DataStructure{id: data_structure_id}, attrs) do
    %DataStructureVersion{data_structure_id: data_structure_id, version: 0}
    |> DataStructureVersion.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a data_structure.

  ## Examples

      iex> update_data_structure(data_structure, %{field: new_value})
      {:ok, %DataStructure{}}

      iex> update_data_structure(data_structure, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_data_structure(data_structure, attrs, opts \\ [])

  def update_data_structure(
        %DataStructure{} = data_structure,
        %{"df_content" => content} = attrs,
        opts
      )
      when not is_nil(content) do
    %{type: type} = get_latest_version(data_structure)

    case TemplateCache.get_by_name!(type) do
      %{:content => content_schema} ->
        attrs =
          data_structure
          |> add_no_updated_fields(attrs, opts[:bulk])

        content_changeset =
          Validation.build_changeset(Map.get(attrs, "df_content"), content_schema)

        case content_changeset.valid? do
          false -> {:error, content_changeset}
          _ -> do_update_data_structure(data_structure, attrs, opts)
        end

      _ ->
        {:error, "Invalid template"}
    end
  end

  def update_data_structure(%DataStructure{} = data_structure, attrs, opts) do
    do_update_data_structure(data_structure, attrs, opts)
  end

  defp do_update_data_structure(%DataStructure{} = data_structure, attrs, opts) do
    data_structure
    |> DataStructure.update_changeset(attrs)
    |> Repo.update()
    |> reindex(opts[:reindex])
  end

  defp reindex({:ok, %{id: id}} = result, true) do
    IndexWorker.reindex(id)
    result
  end

  defp reindex(result, _), do: result

  defp add_no_updated_fields(%DataStructure{:df_content => nil} = _data_structure, attrs, true),
    do: attrs

  defp add_no_updated_fields(data_structure, attrs, true) do
    new_content =
      Map.merge(Map.get(attrs, "df_content"), data_structure.df_content, fn _k, v1, _v2 -> v1 end)

    Map.put(attrs, "df_content", new_content)
  end

  defp add_no_updated_fields(_data_structure, attrs, _), do: attrs

  @doc """
  Deletes a DataStructure.

  ## Examples

      iex> delete_data_structure(data_structure)
      {:ok, %DataStructure{}}

      iex> delete_data_structure(data_structure)
      {:error, %Ecto.Changeset{}}

  """
  def delete_data_structure(%DataStructure{} = data_structure) do
    data_structure = Repo.preload(data_structure, :versions)

    result = Repo.delete(data_structure)

    case result do
      {:ok, _} ->
        data_structure
        |> Map.get(:versions)
        |> Enum.map(& &1.id)
        |> IndexWorker.delete()

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

  def get_latest_version(target, options \\ [])

  @doc """
  Returns the latest data structure version for a given data structure.
  """
  def get_latest_version(%DataStructure{versions: versions}, options) when is_list(versions) do
    versions
    |> Enum.max_by(& &1.version)
    |> enrich(options)
  end

  @doc """
  Returns the latest data structure version for a given data structure.
  """
  def get_latest_version(%DataStructure{id: id}, options) do
    get_latest_version(id, options)
  end

  @doc """
  Returns the latest data structure version for a given data structure id;

  ## Examples

      iex> get_latest_version(1)
      %DataStructureVersion{}

  """
  def get_latest_version(data_structure_id, options) do
    from(dsv in DataStructureVersion,
      where: dsv.data_structure_id == type(^data_structure_id, :integer),
      order_by: [desc: :version],
      limit: 1,
      select: dsv,
      preload: :data_structure
    )
    |> Repo.one()
    |> enrich(options)
  end

  def add_domain_id(data, domain_map, domain_name) do
    data |> Map.put("domain_id", Map.get(domain_map, domain_name)) |> Map.put("ou", domain_name)
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

  def get_field_external_ids(%{data_fields: data_fields}) do
    data_fields
    |> Repo.preload(data_structure: :system)
    |> Enum.map(
      &Map.put(
        &1,
        :external_id,
        StructureCache.get_external_id(
          &1.data_structure.system.external_id,
          &1.data_structure.external_id
        )
      )
    )
  end

  def get_field_links(%{data_fields: data_fields}) do
    data_fields
    |> Enum.map(
      &Map.put(
        &1,
        :links,
        get_structure_links(&1.data_structure_id)
      )
    )
  end

  def get_structure_links(structure_id) do
    case LinkCache.list("data_structure", structure_id) do
      {:ok, links} -> links
      _ -> []
    end
  end

  def get_path(%DataStructureVersion{} = dsv) do
    dsv
    |> get_ancestry
    |> Enum.map(& &1.name)
    |> Enum.reverse()
  end

  def get_ancestors(dsv, opts \\ [deleted: false]) do
    get_recursive(dsv, :parents, opts)
  end

  def get_descendents(dsv, opts \\ [deleted: false]) do
    get_recursive(dsv, :children, opts)
  end

  defp get_recursive(%DataStructureVersion{} = dsv, key, opts) do
    case Map.get(dsv, key) do
      %NotLoaded{} ->
        dsv |> Repo.preload(key) |> get_recursive(key, opts)

      [] ->
        []

      dsvs ->
        dsvs =
          case opts[:deleted] do
            false -> Enum.reject(dsvs, & &1.deleted_at)
            _ -> dsvs
          end

        dsvs ++ Enum.flat_map(dsvs, &get_recursive(&1, key, opts))
    end
  end

  defp get_ancestry(%DataStructureVersion{parents: %NotLoaded{}} = data_structure_version) do
    data_structure_version
    |> Repo.preload(:parents)
    |> get_ancestry
  end

  defp get_ancestry(%DataStructureVersion{parents: []}), do: []

  defp get_ancestry(%DataStructureVersion{parents: parents}) do
    case get_first_active_parent(parents) do
      nil -> []
      parent -> [parent | get_ancestry(parent)]
    end
  end

  defp get_first_active_parent(parents) do
    parents
    |> Enum.find(&(&1.deleted_at == nil))
  end

  def get_structure_by_external_ids(system_external_id, external_id) do
    DataStructure
    |> join(:inner, [system], s in assoc(system, :system))
    |> where([_, s], s.external_id == ^system_external_id)
    |> where([d, _], d.external_id == ^external_id)
    |> Repo.one()
  end

  def get_latest_version_by_external_id(external_id, options \\ []) do
    DataStructureVersion
    |> with_deleted(options, dynamic([dsv], is_nil(dsv.deleted_at)))
    |> join(:inner, [data_structure], ds in assoc(data_structure, :data_structure))
    |> where([_, ds], ds.external_id == ^external_id)
    |> order_by([dsv, ds], desc: dsv.version)
    |> limit(1)
    |> Repo.one()
    |> enrich(options[:enrich])
  end

  defp with_deleted(query, options, dynamic) when is_list(options) do
    include_deleted = Keyword.get(options, :deleted, true)
    with_deleted(query, include_deleted, dynamic)
  end

  defp with_deleted(query, true, _), do: query

  defp with_deleted(query, _false, dynamic) do
    query
    |> where(^dynamic)
  end

  @doc """
  Returns the list of profiles.

  ## Examples

      iex> list_profiles()
      [%Profile{}, ...]

  """
  def list_profiles do
    Repo.all(Profile)
  end

  @doc """
  Gets a single profile.

  Raises `Ecto.NoResultsError` if the Profile does not exist.

  ## Examples

      iex> get_profile!(123)
      %Profile{}

      iex> get_profile!(456)
      ** (Ecto.NoResultsError)

  """
  def get_profile!(id), do: Repo.get!(Profile, id)

  @doc """
  Creates a profile.

  ## Examples

      iex> create_profile(%{field: value})
      {:ok, %Profile{}}

      iex> create_profile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_profile(attrs \\ %{}) do
    %Profile{}
    |> Profile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a profile.

  ## Examples

      iex> update_profile(profile, %{field: new_value})
      {:ok, %Profile{}}

      iex> update_profile(profile, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_profile(%Profile{} = profile, attrs) do
    profile
    |> Profile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Profile.

  ## Examples

      iex> delete_profile(profile)
      {:ok, %Profile{}}

      iex> delete_profile(profile)
      {:error, %Ecto.Changeset{}}

  """
  def delete_profile(%Profile{} = profile) do
    Repo.delete(profile)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking profile changes.

  ## Examples

      iex> change_profile(profile)
      %Ecto.Changeset{source: %Profile{}}

  """
  def change_profile(%Profile{} = profile) do
    Profile.changeset(profile, %{})
  end
end
