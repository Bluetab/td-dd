defmodule TdDd.DataStructures do
  @moduledoc """
  The DataStructures context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Association.NotLoaded
  alias Ecto.Multi
  alias TdCache.LinkCache
  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Lineage.GraphData
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker

  @doc """
  Returns the list of data_structures.

  ## Examples

      iex> list_data_structures()
      [%DataStructure{}, ...]

  """
  def list_data_structures(clauses \\ %{}, options \\ []) do
    clauses
    |> Enum.reduce(DataStructure, fn
      {:external_id, external_ids}, q when is_list(external_ids) ->
        where(q, [ds], ds.external_id in ^external_ids)

      {:external_id, external_id}, q ->
        where(q, [ds], ds.external_id == ^external_id)

      {:domain_id, domain_id}, q when is_list(domain_id) ->
        where(q, [ds], ds.domain_id in ^domain_id)

      {:domain_id, domain_id}, q ->
        where(q, [ds], ds.domain_id == ^domain_id)

      {:id, {:in, ids}}, q ->
        where(q, [ds], ds.id in ^ids)
    end)
    |> preload(:system)
    |> Repo.all()
    |> Enum.map(&enrich(&1, options))
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

  @doc """
  Gets a single data_structure by external_id.

  Returns nil if the Data structure does not exist.

  ## Examples

      iex> get_data_structure_by_external_id!(123)
      %DataStructure{}

      iex> get_data_structure_by_external_id(456)
      ** nil

  """
  def get_data_structure_by_external_id(external_id) do
    Repo.get_by(DataStructure, external_id: external_id)
  end

  @doc """
  Gets a single data_structure_version.

  Raises `Ecto.NoResultsError` if the Data structure version does not exist.

  ## Examples

      iex> get_data_structure!(123)
      %DataStructureVersion{}

      iex> get_data_structure!(456)
      ** (Ecto.NoResultsError)

  """
  def get_data_structure_version!(id) do
    DataStructureVersion
    |> Repo.get!(id)
    |> Repo.preload(:data_structure)
  end

  def get_data_structures(ids, preload \\ :system) do
    from(ds in DataStructure, where: ds.id in ^ids, preload: ^preload, select: ds)
    |> Repo.all()
  end

  def get_data_structure_version!(data_structure_id, version, options) do
    params = %{data_structure_id: data_structure_id, version: version}

    DataStructureVersion
    |> Repo.get_by!(params)
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
    |> enrich(options, :versions, &Repo.preload(&1, :versions))
    |> enrich(options, :latest, &get_latest_version/1)
    |> enrich(options, :domain, &get_domain/1)
    |> enrich(options, :metadata_versions, &get_metadata_versions/1)
  end

  defp enrich(%DataStructureVersion{} = dsv, options) do
    deleted = not is_nil(Map.get(dsv, :deleted_at))
    preload = if Enum.member?(options, :profile), do: [data_structure: :profile], else: []

    dsv
    |> enrich(options, :system, &get_system/1)
    |> enrich(options, :parents, &get_parents(&1, deleted: deleted))
    |> enrich(options, :children, &get_children(&1, deleted: deleted))
    |> enrich(options, :siblings, &get_siblings(&1, deleted: deleted))
    |> enrich(
      options,
      :data_fields,
      &get_field_structures(&1, deleted: deleted, preload: preload)
    )
    |> enrich(options, :data_field_degree, &get_field_degree/1)
    |> enrich(options, :data_field_links, &get_field_links/1)
    |> enrich(options, :relations, &get_relations(&1, deleted: deleted, default: false))
    |> enrich(options, :relation_links, &get_relation_links/1)
    |> enrich(options, :versions, &get_versions/1)
    |> enrich(options, :degree, &get_degree/1)
    |> enrich(options, :profile, &get_profile/1)
    |> enrich(options, :ancestry, &get_ancestry/1)
    |> enrich(options, :path, &get_path/1)
    |> enrich(options, :links, &get_structure_links/1)
    |> enrich(options, :domain, &get_domain/1)
    |> enrich(options, :metadata_versions, &get_metadata_versions/1)
    |> enrich(options, :data_structure_type, &get_data_structure_type/1)
  end

  defp enrich(%{} = target, options, key, fun) do
    target_key = get_target_key(key)

    case Enum.member?(options, key) do
      false -> target
      true -> Map.put(target, target_key, fun.(target))
    end
  end

  defp get_target_key(:data_field_degree), do: :data_fields
  defp get_target_key(:data_field_links), do: :data_fields
  defp get_target_key(:relation_links), do: :relations
  defp get_target_key(key), do: key

  defp get_system(%DataStructureVersion{} = dsv) do
    dsv
    |> Repo.preload(data_structure: :system)
    |> Map.get(:data_structure)
    |> Map.get(:system)
  end

  defp get_profile(%DataStructureVersion{} = dsv) do
    dsv
    |> Repo.preload(data_structure: :profile)
    |> Map.get(:data_structure)
    |> Map.get(:profile)
  end

  def get_data_structure_type(%DataStructureVersion{} = dsv) do
    DataStructureType
    |> where([ds_type], ds_type.structure_type == ^dsv.type)
    |> Repo.one()
  end

  def get_field_structures(data_structure_version, options) do
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
    |> join(:inner, [r, _parent, _], r in assoc(r, :relation_type))
    |> with_deleted(
      Keyword.get(options, :deleted),
      dynamic([_, parent, _], is_nil(parent.deleted_at))
    )
    |> relation_type_condition(
      Keyword.get(options, :default),
      dynamic([_, _child, relation_type], relation_type.name == "default"),
      dynamic([_, _child, relation_type], relation_type.name != "default")
    )
    |> order_by([_, child, _], asc: child.data_structure_id, desc: child.version)
    |> distinct([_, child, _], child)
    |> select([r, child, relation_type], %{
      version: child,
      relation: r,
      relation_type: relation_type
    })
    |> Repo.all()
    |> select_structures(Keyword.get(options, :default))
  end

  defp get_parents(%DataStructureVersion{id: id}, options) do
    DataStructureRelation
    |> where([r], r.child_id == ^id)
    |> join(:inner, [r], parent in assoc(r, :parent))
    |> join(:inner, [r, _parent], relation_type in assoc(r, :relation_type))
    |> with_deleted(
      Keyword.get(options, :deleted),
      dynamic([_, parent, _], is_nil(parent.deleted_at))
    )
    |> relation_type_condition(
      Keyword.get(options, :default),
      dynamic([_, _parent, relation_type], relation_type.name == "default"),
      dynamic([_, _parent, relation_type], relation_type.name != "default")
    )
    |> order_by([_, parent, _], asc: parent.data_structure_id, desc: parent.version)
    |> distinct([_, parent, _], parent)
    |> select([r, parent, relation_type], %{
      version: parent,
      relation: r,
      relation_type: relation_type
    })
    |> Repo.all()
    |> select_structures(Keyword.get(options, :default))
  end

  def get_siblings(%DataStructureVersion{id: id}, options \\ []) do
    DataStructureRelation
    |> where([r], r.child_id == ^id)
    |> join(:inner, [r], parent in assoc(r, :parent))
    |> join(:inner, [r, _parent], parent_rt in assoc(r, :relation_type))
    |> join(:inner, [_r, parent, _parent_rt, r_c], r_c in DataStructureRelation,
      on: parent.id == r_c.parent_id
    )
    |> join(:inner, [_r, _parent, _parent_rt, r_c], child_rt in assoc(r_c, :relation_type))
    |> join(:inner, [_r, _parent, _parent_rt, r_c, _child_rt], sibling in assoc(r_c, :child))
    |> with_deleted(
      options,
      dynamic([_r, parent, _parent_rt, _r_c, _child_rt, _sibling], is_nil(parent.deleted_at))
    )
    |> with_deleted(
      options,
      dynamic([_r, parent, _parent_rt, _r_c, _child_rt, sibling], is_nil(sibling.deleted_at))
    )
    |> relation_type_condition(
      Keyword.get(options, :default),
      dynamic([_r, _parent, parent_rt, _r_c, _child_rt, _sibling], parent_rt.name == "default"),
      dynamic([_r, _parent, parent_rt, _r_c, _child_rt, _sibling], parent_rt.name != "default")
    )
    |> relation_type_condition(
      Keyword.get(options, :default),
      dynamic([_r, _parent, _parent_rt, _r_c, child_rt, _sibling], child_rt.name == "default"),
      dynamic([_r, _parent, _parent_rt, _r_c, child_rt, _sibling], child_rt.name != "default")
    )
    |> order_by([_r, _parent, _parent_rt, _r_c, _child_rt, sibling],
      asc: sibling.data_structure_id,
      desc: sibling.version
    )
    |> distinct([_r, _parent, _parent_rt, _r_c, _child_rt, sibling], sibling)
    |> select([_r, _parent, _parent_rt, _r_c, _child_rt, sibling], sibling)
    |> Repo.all()
    |> Enum.uniq_by(& &1.data_structure_id)
  end

  defp get_relations(%DataStructureVersion{} = version, options) do
    parents = get_parents(version, options)
    children = get_children(version, options)

    %{parents: parents, children: children}
  end

  defp get_relation_links(%{relations: relations}) do
    %{parents: parents, children: children} = relations

    children =
      Enum.map(children, fn %{version: dsv} = child ->
        Map.put(child, :links, get_structure_links(dsv))
      end)

    parents =
      Enum.map(parents, fn %{version: dsv} = parent ->
        Map.put(parent, :links, get_structure_links(dsv))
      end)

    relations
    |> Map.put(:children, children)
    |> Map.put(:parents, parents)
  end

  defp get_versions(%DataStructureVersion{} = dsv) do
    dsv
    |> Ecto.assoc([:data_structure, :versions])
    |> Repo.all()
  end

  defp select_structures(versions, false) do
    versions
    |> Enum.uniq_by(& &1.version.data_structure_id)
    |> Enum.map(&preload_system/1)
  end

  defp select_structures(versions, _not_false) do
    versions
    |> Enum.map(& &1.version)
    |> Enum.uniq_by(& &1.data_structure_id)
    |> Repo.preload(data_structure: :system)
  end

  defp preload_system(%{version: v} = version) do
    Map.put(version, :version, Repo.preload(v, data_structure: :system))
  end

  defp get_domain(%DataStructureVersion{data_structure: %NotLoaded{}} = version) do
    version
    |> Repo.preload(:data_structure)
    |> get_domain()
  end

  defp get_domain(%DataStructureVersion{data_structure: data_structure}) do
    domain_id = Map.get(data_structure, :domain_id)

    case domain_id do
      nil -> %{}
      domain_id -> TaxonomyCache.get_domain(domain_id) || %{}
    end
  end

  defp get_domain(%DataStructure{domain_id: nil}), do: %{}

  defp get_domain(%DataStructure{domain_id: domain_id}) do
    TaxonomyCache.get_domain(domain_id) || %{}
  end

  defp get_metadata_versions(%DataStructure{} = data_structure) do
    data_structure
    |> Repo.preload(:metadata_versions)
    |> Repo.get(:metadata_versions)
  end

  defp get_metadata_versions(%DataStructureVersion{} = version) do
    version
    |> Repo.preload(data_structure: :metadata_versions)
    |> Map.get(:data_structure)
    |> Map.get(:metadata_versions)
  end

  @doc """
  Updates a data_structure.

  ## Examples

      iex> update_data_structure(data_structure, %{field: new_value}, user)
      {:ok, %DataStructure{}}

      iex> update_data_structure(data_structure, %{field: bad_value}, user)
      {:error, %Ecto.Changeset{}}

  """
  def update_data_structure(%DataStructure{} = data_structure, %{} = params, %{id: user_id}) do
    changeset = DataStructure.update_changeset(data_structure, params)

    Multi.new()
    |> Multi.update(:data_structure, changeset)
    |> Multi.run(:audit, Audit, :data_structure_updated, [changeset, user_id])
    |> Repo.transaction()
    |> on_update()
  end

  defp on_update({:ok, %{} = res}) do
    with %{data_structure: %{id: id}} <- res do
      IndexWorker.reindex(id)
    end

    {:ok, res}
  end

  defp on_update(res), do: res

  @doc """
  Deletes a DataStructure.

  ## Examples

      iex> delete_data_structure(data_structure, user)
      {:ok, %DataStructure{}}

      iex> delete_data_structure(data_structure, user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_data_structure(%DataStructure{} = data_structure, %{id: user_id}) do
    Multi.new()
    |> Multi.run(:delete_versions, fn _, _ ->
      {:ok, delete_data_structure_versions(data_structure)}
    end)
    |> Multi.delete(:data_structure, data_structure)
    |> Multi.run(:audit, Audit, :data_structure_deleted, [user_id])
    |> Repo.transaction()
    |> on_delete()
  end

  defp delete_data_structure_versions(%DataStructure{id: data_structure_id}) do
    DataStructureVersion
    |> where([dsv], dsv.data_structure_id == ^data_structure_id)
    |> select([dsv], dsv.id)
    |> Repo.delete_all()
  end

  defp on_delete({:ok, %{} = res}) do
    with %{delete_versions: {_count, dsv_ids}} <- res do
      IndexWorker.delete(dsv_ids)
    end

    {:ok, res}
  end

  defp on_delete(res), do: res

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

  def put_domain_id(data, %{} = domain_map, domain) when is_binary(domain) do
    case Map.get(domain_map, domain) do
      nil -> data
      domain_id -> Map.put(data, "domain_id", domain_id)
    end
  end

  def put_domain_id(data, _domain_map, _domain), do: data

  def put_domain_id(%{"domain_id" => domain_id} = data, external_ids)
      when is_nil(domain_id) or domain_id == "" do
    with_domain_id(data, external_ids)
  end

  def put_domain_id(%{"domain_id" => _} = data, _external_ids), do: data

  def put_domain_id(data, external_ids) do
    with_domain_id(data, external_ids)
  end

  defp with_domain_id(data, external_ids) do
    case get_domain_id(data, external_ids) do
      nil -> data
      domain_id -> Map.put(data, "domain_id", domain_id)
    end
  end

  defp get_domain_id(%{"domain_external_id" => external_id}, %{} = external_ids)
       when not is_nil(external_id) and external_id != "" do
    Map.get(external_ids, external_id)
  end

  defp get_domain_id(%{"ou" => ou}, %{} = external_ids)
       when not is_nil(ou) and ou != "" do
    Map.get(external_ids, ou)
  end

  defp get_domain_id(_data, _external_id), do: nil

  def find_data_structure(%{} = clauses) do
    Repo.get_by(DataStructure, clauses)
  end

  defp get_degree(%{data_structure: %{external_id: external_id}}) do
    case GraphData.degree(external_id) do
      {:ok, degree} -> degree
      {:error, _} -> nil
    end
  end

  defp get_degree(_), do: nil

  defp get_field_degree(%{data_fields: data_fields}) do
    data_fields
    |> Repo.preload(data_structure: :system)
    |> Enum.map(&add_degree/1)
  end

  defp add_degree(dsv) do
    dsv
    |> get_degree()
    |> do_add_degree(dsv)
  end

  defp do_add_degree(nil, dsv), do: dsv
  defp do_add_degree(degree, dsv), do: Map.put(dsv, :degree, degree)

  defp get_field_links(%{data_fields: data_fields}) do
    Enum.map(data_fields, &Map.put(&1, :links, get_structure_links(&1)))
  end

  def get_structure_links(%{data_structure_id: id}) do
    case LinkCache.list("data_structure", id) do
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

  defp get_ancestry(%DataStructureVersion{} = data_structure_version) do
    data_structure_version
    |> get_parents(deleted: false)
    |> get_ancestry()
  end

  defp get_ancestry([]), do: []

  defp get_ancestry([parent | _t]), do: [parent | get_ancestry(parent)]

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
    where(query, ^dynamic)
  end

  defp relation_type_condition(query, false, _default, custom), do: where(query, ^custom)

  defp relation_type_condition(query, _not_false, default, _custom),
    do: where(query, ^default)

  @doc """
  Returns a Map whose keys are external ids and whose values are data
  structure ids.
  """
  def external_id_map do
    from(ds in DataStructure, select: {ds.external_id, ds.id})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Creates mutable metadata.

  ## Examples

      iex> create_structure_metadata(%{field: value})
      {:ok, %StructureMetadata{}}

      iex> create_structure_metadata(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_structure_metadata(params) do
    %StructureMetadata{}
    |> StructureMetadata.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Gets a single metadata.

  Raises `Ecto.NoResultsError` if the metadata does not exist.

  ## Examples

      iex> get_structure_metadata!(123)
      %StructureMetadata{}

      iex> get_structure_metadata!(456)
      ** (Ecto.NoResultsError)

  """
  def get_structure_metadata!(id), do: Repo.get!(StructureMetadata, id)

  @doc """
  Updates metadata.

  ## Examples

      iex> update_structure_metadata(structure_metadata, %{field: new_value})
      {:ok, %StructureMetadata{}}

      iex> update_structure_metadata(structure_metadata, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_structure_metadata(%StructureMetadata{} = structure_metadata, params) do
    structure_metadata
    |> StructureMetadata.changeset(params)
    |> Repo.update()
  end

  def get_latest_metadata_version(id, options \\ []) do
    StructureMetadata
    |> where([sm], sm.data_structure_id == ^id)
    |> with_deleted(options, dynamic([sm], is_nil(sm.deleted_at)))
    |> order_by(desc: :version)
    |> limit(1)
    |> preload(:data_structure)
    |> select([sm], sm)
    |> Repo.one()
  end
end
