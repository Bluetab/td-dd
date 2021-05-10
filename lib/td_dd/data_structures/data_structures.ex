defmodule TdDd.DataStructures do
  @moduledoc """
  The DataStructures context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Association.NotLoaded
  alias Ecto.Multi
  alias TdCache.LinkCache
  alias TdCache.StructureTypeCache
  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdCx.Sources
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructuresTags
  alias TdDd.DataStructures.DataStructureTag
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Paths
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Lineage.GraphData
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker
  alias TdDfLib.Format

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
    |> Paths.by_version_id(id)
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
    |> Paths.by_structure_id_and_version(data_structure_id, version)
    |> Repo.get_by!(params)
    |> Repo.preload(data_structure: :system)
    |> enrich(options)
  end

  def get_data_structure_version!(data_structure_version_id, options) do
    DataStructureVersion
    |> Paths.by_version_id(data_structure_version_id)
    |> Repo.get!(data_structure_version_id)
    |> Repo.preload(data_structure: :system)
    |> enrich(options)
  end

  def get_cached_content(%{} = content, %{data_structure_type: %{template_id: template_id}}) do
    case TemplateCache.get(template_id) do
      {:ok, template} ->
        Format.enrich_content_values(content, template)

      _ ->
        content
    end
  end

  def get_cached_content(content, _structure), do: content

  defp enrich(nil = _target, _opts), do: nil

  defp enrich(target, nil = _opts), do: target

  defp enrich(%DataStructure{} = ds, options) do
    ds
    |> enrich(options, :versions, &Repo.preload(&1, :versions))
    |> enrich(options, :latest, &get_latest_version/1)
    |> enrich(options, :domain, &get_domain/1)
    |> enrich(options, :source, &get_source/1)
    |> enrich(options, :metadata_versions, &get_metadata_versions/1)
  end

  defp enrich(%DataStructureVersion{} = dsv, options) do
    deleted = not is_nil(Map.get(dsv, :deleted_at))
    preload = if Enum.member?(options, :profile), do: [data_structure: :profile], else: []
    with_confidential = Enum.member?(options, :with_confidential)

    dsv
    |> enrich(options, :system, &get_system/1)
    |> enrich(
      options,
      :parents,
      &get_parents(&1, deleted: deleted, with_confidential: with_confidential)
    )
    |> enrich(
      options,
      :children,
      &get_children(&1, deleted: deleted, with_confidential: with_confidential)
    )
    |> enrich(
      options,
      :siblings,
      &get_siblings(&1, deleted: deleted, with_confidential: with_confidential)
    )
    |> enrich(
      options,
      :data_fields,
      &get_field_structures(&1,
        deleted: deleted,
        preload: preload,
        with_confidential: with_confidential
      )
    )
    |> enrich(options, :data_field_degree, &get_field_degree/1)
    |> enrich(options, :data_field_links, &get_field_links/1)
    |> enrich(
      options,
      :relations,
      &get_relations(&1, deleted: deleted, default: false, with_confidential: with_confidential)
    )
    |> enrich(options, :relation_links, &get_relation_links/1)
    |> enrich(options, :versions, &get_versions/1)
    |> enrich(options, :degree, &get_degree/1)
    |> enrich(options, :profile, &get_profile/1)
    |> enrich(options, :links, &get_structure_links/1)
    |> enrich(options, :domain, &get_domain/1)
    |> enrich(options, :source, &get_source/1)
    |> enrich(options, :metadata_versions, &get_metadata_versions/1)
    |> enrich(options, :data_structure_type, &get_data_structure_type/1)
    |> enrich(options, :tags, &get_tags/1)
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
    |> where([child], child.class == "field")
    |> join(:inner, [child], child in assoc(child, :data_structure))
    |> with_confidential(
      Keyword.get(options, :with_confidential),
      dynamic([_child, _parent, _rel, child_ds], child_ds.confidential == false)
    )
    |> with_deleted(options, dynamic([child], is_nil(child.deleted_at)))
    |> select([child], child)
    |> Repo.all()
    |> Repo.preload(options[:preload] || [])
  end

  def get_children(%DataStructureVersion{id: id}, options \\ []) do
    DataStructureRelation
    |> where([r], r.parent_id == ^id)
    |> join(:inner, [r], parent in assoc(r, :child))
    |> join(:inner, [r, _parent, _], r in assoc(r, :relation_type))
    |> join(:inner, [_r, child, _], child in assoc(child, :data_structure))
    |> with_deleted(
      Keyword.get(options, :deleted),
      dynamic([_, parent, _], is_nil(parent.deleted_at))
    )
    |> with_confidential(
      Keyword.get(options, :with_confidential),
      dynamic([_, _child, _, ds_child], ds_child.confidential == false)
    )
    |> relation_type_condition(
      Keyword.get(options, :default),
      dynamic([_, _child, relation_type, _], relation_type.name == "default"),
      dynamic([_, _child, relation_type, _], relation_type.name != "default")
    )
    |> order_by([_, child, _, _], asc: child.data_structure_id, desc: child.version)
    |> distinct([_, child, _, _], child)
    |> select([r, child, relation_type, _], %{
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
    |> join(:inner, [_r, parent, _relation_type], parent in assoc(parent, :data_structure))
    |> with_deleted(
      Keyword.get(options, :deleted),
      dynamic([_, parent, _, _], is_nil(parent.deleted_at))
    )
    |> relation_type_condition(
      Keyword.get(options, :default),
      dynamic([_, _parent, relation_type, _], relation_type.name == "default"),
      dynamic([_, _parent, relation_type, _], relation_type.name != "default")
    )
    |> with_confidential(
      Keyword.get(options, :with_confidential),
      dynamic([_, _parent, _relation_type, parent_ds], parent_ds.confidential == false)
    )
    |> order_by([_, parent, _, _], asc: parent.data_structure_id, desc: parent.version)
    |> distinct([_, parent, _, _], parent)
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
    |> join(
      :inner,
      [_r, _parent, _parent_rt, _r_c, _child_rt, sibling],
      sibling in assoc(sibling, :data_structure)
    )
    |> with_deleted(
      options,
      dynamic(
        [_r, parent, _parent_rt, _r_c, _child_rt, _sibling, _sibling_ds],
        is_nil(parent.deleted_at)
      )
    )
    |> with_deleted(
      options,
      dynamic(
        [_r, parent, _parent_rt, _r_c, _child_rt, sibling, _sibling_ds],
        is_nil(sibling.deleted_at)
      )
    )
    |> with_confidential(
      Keyword.get(options, :with_confidential),
      dynamic(
        [_r, _parent, _parent_rt, _r_c, _child_rt, _sibling, sibling_ds],
        sibling_ds.confidential == false
      )
    )
    |> relation_type_condition(
      Keyword.get(options, :default),
      dynamic(
        [_r, _parent, parent_rt, _r_c, _child_rt, _sibling, _sibling_ds],
        parent_rt.name == "default"
      ),
      dynamic(
        [_r, _parent, parent_rt, _r_c, _child_rt, _sibling, _sibling_ds],
        parent_rt.name != "default"
      )
    )
    |> relation_type_condition(
      Keyword.get(options, :default),
      dynamic(
        [_r, _parent, _parent_rt, _r_c, child_rt, _sibling, _sibling_ds],
        child_rt.name == "default"
      ),
      dynamic(
        [_r, _parent, _parent_rt, _r_c, child_rt, _sibling, _sibling_ds],
        child_rt.name != "default"
      )
    )
    |> order_by([_r, _parent, _parent_rt, _r_c, _child_rt, sibling, _sibling_ds],
      asc: sibling.data_structure_id,
      desc: sibling.version
    )
    |> distinct([_r, _parent, _parent_rt, _r_c, _child_rt, sibling, _sibling_ds], sibling)
    |> select([_r, _parent, _parent_rt, _r_c, _child_rt, sibling, _sibling_ds], sibling)
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

  def get_source(%DataStructureVersion{data_structure: %DataStructure{} = data_structure}) do
    get_source(data_structure)
  end

  def get_source(%DataStructureVersion{} = version) do
    version
    |> Repo.preload(data_structure: :source)
    |> Kernel.get_in([:data_structure, :source])
  end

  def get_source(%DataStructure{source: %NotLoaded{}} = data_structure) do
    data_structure
    |> Repo.preload(:source)
    |> Map.get(:source)
  end

  def get_source(%DataStructure{source: source}), do: source

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

  defp get_tags(%DataStructureVersion{data_structure: %DataStructure{} = data_structure}) do
    get_tags(data_structure)
  end

  defp get_tags(%DataStructureVersion{} = version) do
    version
    |> Repo.preload(:data_structure)
    |> Map.get(:data_structure)
    |> get_tags()
  end

  defp get_tags(%DataStructure{} = data_structure) do
    data_structure
    |> Repo.preload(data_structures_tags: [:data_structure_tag, :data_structure])
    |> Map.get(:data_structures_tags)
  end

  @doc """
  Updates a data_structure.

  ## Examples

      iex> update_data_structure(data_structure, %{field: new_value}, claims)
      {:ok, %DataStructure{}}

      iex> update_data_structure(data_structure, %{field: bad_value}, claims)
      {:error, %Ecto.Changeset{}}

  """
  def update_data_structure(%DataStructure{} = data_structure, %{} = params, %Claims{
        user_id: user_id
      }) do
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

      iex> delete_data_structure(data_structure, claims)
      {:ok, %DataStructure{}}

      iex> delete_data_structure(data_structure, claims)
      {:error, %Ecto.Changeset{}}

  """
  def delete_data_structure(%DataStructure{} = data_structure, %Claims{user_id: user_id}) do
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
    |> select([dsv], dsv.data_structure_id)
    |> Repo.delete_all()
  end

  defp on_delete({:ok, %{} = res}) do
    with %{delete_versions: {_count, data_structure_ids}} <- res do
      IndexWorker.delete(data_structure_ids)
    end

    {:ok, res}
  end

  defp on_delete(res), do: res

  @doc """
  Returns the latest data structure version for a given data structure id;

  ## Examples

      iex> get_latest_version(1)
      %DataStructureVersion{}

  """
  def get_latest_version(target, options \\ [])

  def get_latest_version(%DataStructure{versions: versions}, options) when is_list(versions) do
    versions
    |> Enum.max_by(& &1.version)
    |> enrich(options)
  end

  def get_latest_version(%DataStructure{id: id}, options) do
    get_latest_version(id, options)
  end

  def get_latest_version(data_structure_id, options) do
    DataStructureVersion
    |> Paths.by_data_structure_id(data_structure_id)
    |> where([dsv], dsv.data_structure_id == type(^data_structure_id, :integer))
    |> preload(data_structure: :source)
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
    end
  end

  def get_structure_links(%{data_structure_id: id}, resource_type) do
    case LinkCache.list("data_structure", id, resource_type) do
      {:ok, links} -> links
    end
  end

  def get_path(%DataStructureVersion{path: %{names: [_ | names]}}) do
    Enum.reverse(names)
  end

  def get_path(_), do: []

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

  def get_latest_version_by_external_id(external_id, options \\ []) do
    DataStructureVersion
    |> with_deleted(options, dynamic([dsv], is_nil(dsv.deleted_at)))
    |> distinct(:data_structure_id)
    |> order_by(desc: :version)
    |> join(:inner, [data_structure], ds in assoc(data_structure, :data_structure))
    |> where([_, ds], ds.external_id == ^external_id)
    |> select_merge([_, ds], %{external_id: ds.external_id})
    |> Repo.one()
    |> enrich(options[:enrich])
  end

  @spec get_latest_versions([non_neg_integer]) :: [DataStructureVersion.t()]
  def get_latest_versions(structure_ids) when is_list(structure_ids) do
    DataStructureVersion
    |> distinct(:data_structure_id)
    |> order_by(desc: :version)
    |> where([dsv], dsv.data_structure_id in ^structure_ids)
    |> Repo.all()
  end

  defp with_deleted(query, options, dynamic) when is_list(options) do
    include_deleted = Keyword.get(options, :deleted, true)
    with_deleted(query, include_deleted, dynamic)
  end

  defp with_deleted(query, true, _), do: query

  defp with_deleted(query, _false, dynamic) do
    where(query, ^dynamic)
  end

  defp with_confidential(query, true, _), do: query

  defp with_confidential(query, _false, dynamic) do
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

  def get_structures_metadata_fields(clauses \\ %{}) do
    clauses
    |> Enum.reduce(DataStructureVersion, fn
      {:type, types}, q when is_list(types) ->
        where(q, [dsv], dsv.type in ^types)

      {:type, type}, q ->
        where(q, [dsv], dsv.type == ^type)

      _, q ->
        q
    end)
    |> where([dsv], is_nil(dsv.deleted_at))
    |> select([_dsv], fragment("jsonb_object_keys(metadata)"))
    |> distinct(true)
    |> Repo.all()
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

  def get_metadata_version(%DataStructureVersion{
        data_structure_id: structure_id,
        inserted_at: inserted_at,
        deleted_at: deleted_at
      }) do
    StructureMetadata
    |> where([sm], sm.data_structure_id == ^structure_id)
    |> where(
      [sm],
      fragment(
        "(?, COALESCE(?, NOW())) OVERLAPS (?, COALESCE(?, NOW()))",
        ^inserted_at,
        ^deleted_at,
        sm.inserted_at,
        sm.deleted_at
      )
    )
    |> order_by(desc: :version)
    |> distinct(:data_structure_id)
    |> Repo.one()
  end

  def template_name(%DataStructure{} = data_structure) do
    data_structure
    |> get_latest_version()
    |> template_name()
  end

  def template_name(%DataStructureVersion{type: type}) do
    with {:ok, %{template_id: template_id}} <- StructureTypeCache.get_by_type(type),
         {:ok, %{name: name}} <- TemplateCache.get(template_id) do
      name
    else
      _ -> ""
    end
  end

  def template_name(_), do: nil

  def get_latest_metadata_by_external_ids(external_ids) do
    DataStructure
    |> where([ds], ds.external_id in ^external_ids)
    |> join(:left, [ds], m in subquery(latest_mutable_metadata_query()),
      on: m.data_structure_id == ds.id
    )
    |> select_merge([ds, m], %{latest_metadata: m})
    |> Repo.all()
  end

  @spec latest_mutable_metadata_query :: Ecto.Query.t()
  def latest_mutable_metadata_query do
    StructureMetadata
    |> distinct(:data_structure_id)
    |> order_by(asc: :data_structure_id, desc: :version)
  end

  def profile_source(
        %{data_structure: %{source: %{config: %{"job_types" => job_types}} = source}} = dsv
      ) do
    if Enum.member?(job_types, "profile") do
      Map.put(dsv, :profile_source, source)
    else
      do_profile_source(dsv, source)
    end
  end

  def profile_source(dsv), do: dsv

  defp do_profile_source(dsv, %{config: %{"alias" => source_alias}})
       when not is_nil(source_alias) do
    case Sources.get_source(%{external_id: source_alias}) do
      %{config: %{"job_types" => job_types}} = source ->
        if Enum.member?(job_types, "profile") do
          Map.put(dsv, :profile_source, source)
        else
          dsv
        end

      _ ->
        dsv
    end
  end

  defp do_profile_source(dsv, _source), do: dsv

  @doc """
  Returns the list of data_structure_tags.

  ## Examples

      iex> list_data_structure_tags()
      [%DataStructureTag{}, ...]

  """
  def list_data_structure_tags do
    Repo.all(DataStructureTag)
  end

  @doc """
  Gets a single data_structure_tag.

  Raises `Ecto.NoResultsError` if the Data structure tag does not exist.

  ## Examples

      iex> get_data_structure_tag!(123)
      %DataStructureTag{}

      iex> get_data_structure_tag!(456)
      ** (Ecto.NoResultsError)

  """
  def get_data_structure_tag!(id), do: Repo.get!(DataStructureTag, id)

  @doc """
  Creates a data_structure_tag.

  ## Examples

      iex> create_data_structure_tag(%{field: value})
      {:ok, %DataStructureTag{}}

      iex> create_data_structure_tag(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_data_structure_tag(attrs \\ %{}) do
    %DataStructureTag{}
    |> DataStructureTag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a data_structure_tag.

  ## Examples

      iex> update_data_structure_tag(data_structure_tag, %{field: new_value})
      {:ok, %DataStructureTag{}}

      iex> update_data_structure_tag(data_structure_tag, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_data_structure_tag(%DataStructureTag{} = data_structure_tag, attrs) do
    data_structure_tag
    |> DataStructureTag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a data_structure_tag.

  ## Examples

      iex> delete_data_structure_tag(data_structure_tag)
      {:ok, %DataStructureTag{}}

      iex> delete_data_structure_tag(data_structure_tag)
      {:error, %Ecto.Changeset{}}

  """
  def delete_data_structure_tag(%DataStructureTag{} = data_structure_tag) do
    Repo.delete(data_structure_tag)
  end

  @doc """
  Returns the links between a data structure and its tags.

  ## Examples

      iex> get_links_tag(%DataStructure{})
      [%DataStructuresTags{}, ...]

  """

  def get_links_tag(%DataStructure{data_structures_tags: tags})
      when is_list(tags) do
    tags
  end

  def get_links_tag(%DataStructure{} = data_structure) do
    data_structure
    |> Repo.preload(data_structures_tags: [:data_structure, :data_structure_tag])
    |> Map.get(:data_structures_tags)
  end

  @doc """
  links a tag to a structure.

  ## Examples

      iex> link_tag(data_structure, data_structure_tag, params)
      {:ok, %DataStructureTag{}}

      iex> link_tag(data_structure, data_structure_tag, params)
      {:error, %Ecto.Changeset{}}

  """
  def link_tag(
        %DataStructure{id: data_structure_id} = data_structure,
        %DataStructureTag{id: tag_id} = data_structure_tag,
        params
      ) do
    data_structure_id
    |> get_link_tag_by(tag_id)
    |> case do
      nil -> create_link(data_structure, data_structure_tag, params)
      %DataStructuresTags{} = tag_link -> update_link(tag_link, params)
    end
  end

  @doc """
  deletes a link between a tag to a structure.

  ## Examples

      iex> delete_link_tag(data_structure, data_structure_tag)
      {:ok, %DataStructuresTags{}}

      iex> delete_link_tag(data_structure, data_structure_tag)
      {:error, %Ecto.Changeset{}}

  """
  def delete_link_tag(
        %DataStructure{id: data_structure_id},
        %DataStructureTag{id: tag_id}
      ) do
    data_structure_id
    |> get_link_tag_by(tag_id)
    |> case do
      nil -> {:error, :not_found}
      %DataStructuresTags{} = tag_link -> 
        tag_link
        |> Repo.delete() 
        |> on_link_delete()
    end
  end

  def get_link_tag_by(data_structure_id, tag_id) do
    Repo.get_by(DataStructuresTags,
      data_structure_tag_id: tag_id,
      data_structure_id: data_structure_id
    )
  end

  defp create_link(data_structure, data_structure_tag, params) do
    params
    |> DataStructuresTags.changeset()
    |> DataStructuresTags.put_data_structure(data_structure)
    |> DataStructuresTags.put_data_structure_tag(data_structure_tag)
    |> Repo.insert()
    |> on_link_insert()
  end

  defp update_link(link, params) do
    link
    |> DataStructuresTags.changeset(params)
    |> Repo.update()
    |> on_link_update()
  end

  defp on_link_insert({:ok, link}) do
    IndexWorker.reindex(link.data_structure_id)
    {:ok, link}
  end

  defp on_link_insert(reply), do: reply

  defp on_link_delete({:ok, link}) do
    IndexWorker.reindex(link.data_structure_id)
    {:ok, link}
  end

  defp on_link_delete(reply), do: reply

  defp on_link_update({:ok, link}),
    do: {:ok, Repo.preload(link, [:data_structure_tag, :data_structure])}

  defp on_link_update(reply), do: reply
end
