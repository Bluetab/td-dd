defmodule TdDd.DataStructures do
  @moduledoc """
  The DataStructures context.
  """

  import Ecto.Query

  alias Ecto.Association.NotLoaded
  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.LinkCache
  alias TdCache.TemplateCache
  alias TdCache.UserCache
  alias TdCluster.Cluster.TdAi.Embeddings
  alias TdCluster.Cluster.TdAi.Indices
  alias TdCore.Search.IndexWorker
  alias TdCore.Search.Permissions
  alias TdCx.Sources
  alias TdCx.Sources.Source
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureLinks
  alias TdDd.DataStructures.DataStructureQueries
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.DataStructureVersions.RecordEmbedding
  alias TdDd.DataStructures.RecordEmbeddings
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.DataStructures.Search.Indexer
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Grants
  alias TdDd.Grants.Requests
  alias TdDd.Lineage.GraphData
  alias TdDd.Repo
  alias TdDd.Search.StructureVersionEnricher
  alias TdDfLib.Format
  alias TdDq.Implementations
  alias Truedat.Auth.Claims

  @index :structures

  @protected "_protected"

  # Data structure version associations preloaded for some views
  @preload_dsv_assocs [
    :published_note,
    :structure_type,
    :classifications,
    data_structure: :system
  ]

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  def protected, do: @protected

  def list_data_structures(clauses \\ %{}) do
    clauses
    |> DataStructureQueries.data_structures_query()
    |> Repo.all()
  end

  def list_data_structure_versions(clauses \\ %{}) do
    criteria_apply_order = [:min_id, :since, :order_by, :limit]

    criteria_apply_order
    |> Enum.filter(&Map.has_key?(clauses, &1))
    |> Enum.map(&{&1, Map.get(clauses, &1)})
    |> Enum.reduce(DataStructureVersion, fn
      {:since, since}, q ->
        q
        |> join(:inner, [dsv], ds in assoc(dsv, :data_structure))
        |> where(
          [dsv, ds],
          dsv.updated_at >= ^since or dsv.deleted_at >= ^since or ds.updated_at >= ^since
        )

      {:min_id, id}, q ->
        where(q, [dsv], dsv.id >= ^id)

      {:order_by, "id"}, q ->
        # Use literal instead of named field in case order_by is used with
        # the union from the :since clause above, to avoid this error:
        # ** (Postgrex.Error) ERROR 42P01 (undefined_table) missing
        # FROM-clause entry for table "d0"
        order_by(q, fragment("id"))

      {:limit, limit}, q ->
        limit(q, ^limit)
    end)
    |> Repo.all()
  end

  def get_data_structure!(id, preload \\ [:system]) do
    DataStructure
    |> Repo.get!(id)
    |> Repo.preload(preload)
  end

  def get_data_structure(id), do: Repo.get(DataStructure, id)

  def list_data_structure_versions_by_criteria(criteria) do
    criteria
    |> Enum.reduce(DataStructureVersion, fn
      {:not_deleted, _}, q ->
        where(q, [dsv], is_nil(dsv.deleted_at))

      {:name, name}, q ->
        where(q, [dsv], fragment("lower(?) = lower(?)", dsv.name, ^name))

      {:name_in, names}, q ->
        lower_names = Enum.map(names, &String.downcase/1)
        where(q, [dsv], fragment("lower(?)", dsv.name) in ^lower_names)

      {:class, class}, q ->
        where(q, [dsv], dsv.class == ^class)

      {:metadata_field, {key, value}}, q ->
        where(q, [dsv], fragment("lower(?->>?) = lower(?)", dsv.metadata, ^key, ^value))

      {:metadata_field_in, {key, values}}, q ->
        lower_values = Enum.map(values, &String.downcase/1)
        where(q, [dsv], fragment("lower(?->>?) = ANY(?)", dsv.metadata, ^key, ^lower_values))

      {:source_id, source_id}, q ->
        q
        |> join(:inner, [dsv], ds in assoc(dsv, :data_structure))
        |> where([_dsv, ds], ds.source_id == ^source_id)
    end)
    |> Repo.all()
  end

  def list_data_structures_data_fields(data_structure_ids, claims) do
    %{
      "view_data_structure" => view_domain_ids,
      "manage_confidential_structures" => manage_confidential_domain_ids
    } =
      ["view_data_structure", "manage_confidential_structures"]
      |> Permissions.get_search_permissions(claims)

    DataStructure
    |> where([ds], ds.id in ^data_structure_ids)
    |> join(:inner, [ds], dsv in assoc(ds, :current_version))
    |> join(:inner, [_, dsv], child in assoc(dsv, :children))
    |> where([_, _, child], child.class == "field")
    |> join(:inner, [_, _, child], child_ds in assoc(child, :data_structure), as: :child_ds)
    |> handle_permission_filter(view_domain_ids, manage_confidential_domain_ids)
    |> select([ds, _, child, child_ds], %{
      id: ds.id,
      data_field: %{child | data_structure: child_ds}
    })
    |> Repo.all()
  end

  defp handle_permission_filter(query, :all, :all), do: query
  defp handle_permission_filter(query, :none, _), do: where(query, [], false)

  defp handle_permission_filter(query, :all, :none),
    do: where(query, [_, _, _, child_ds], not child_ds.confidential)

  defp handle_permission_filter(query, :all, domain_ids),
    do:
      where(
        query,
        [_, _, _, child_ds],
        not child_ds.confidential or fragment("? && ?", child_ds.domain_ids, ^domain_ids)
      )

  defp handle_permission_filter(query, view_domain_ids, :none),
    do:
      where(
        query,
        [_, _, _, child_ds],
        not child_ds.confidential and fragment("? && ?", child_ds.domain_ids, ^view_domain_ids)
      )

  defp handle_permission_filter(query, view_domain_ids, :all),
    do:
      where(query, [_, _, _, child_ds], fragment("? && ?", child_ds.domain_ids, ^view_domain_ids))

  defp handle_permission_filter(query, view_domain_ids, confidential_domain_ids),
    do:
      where(
        query,
        [_, _, _, child_ds],
        (not child_ds.confidential and fragment("? && ?", child_ds.domain_ids, ^view_domain_ids)) or
          fragment("? && ?", child_ds.domain_ids, ^confidential_domain_ids)
      )

  @doc "Gets a single data_structure by external_id"
  def get_data_structure_by_external_id(external_id, preload \\ []) do
    Repo.get_by(DataStructure, external_id: external_id)
    |> Repo.preload(preload)
  end

  def get_data_structures(ids, preload \\ :system) do
    from(ds in DataStructure, where: ds.id in ^ids, preload: ^preload, select: ds)
    |> Repo.all()
  end

  def get_data_structure_version!(id, version \\ nil, enrich_fields \\ [], opts \\ [])

  def get_data_structure_version!(id, nil, [], []), do: do_get_data_structure_version!(id)

  def get_data_structure_version!(id, [_ | _] = enrich_or_opts, [], [])
      when is_list(enrich_or_opts) do
    if Keyword.keyword?(enrich_or_opts) do
      do_get_data_structure_version!(id, [], enrich_or_opts)
    else
      do_get_data_structure_version!(id, enrich_or_opts, [])
    end
  end

  def get_data_structure_version!(id, enrich_fields, opts, [])
      when is_list(enrich_fields) and is_list(opts),
      do: do_get_data_structure_version!(id, enrich_fields, opts)

  def get_data_structure_version!(id, version, [_ | _] = enrich_or_opts, []) do
    if Keyword.keyword?(enrich_or_opts) do
      do_get_data_structure_version!(id, version, [], enrich_or_opts)
    else
      do_get_data_structure_version!(id, version, enrich_or_opts, [])
    end
  end

  def get_data_structure_version!(id, version, enrich_fields, opts),
    do: do_get_data_structure_version!(id, version, enrich_fields, opts)

  defp do_get_data_structure_version!(id), do: enriched_structure_version!(id)

  defp do_get_data_structure_version!(data_structure_version_id, enrich_fields, opts) do
    with_protected_metadata = Enum.member?(enrich_fields, :with_protected_metadata)

    data_structure_version_id
    |> enriched_structure_version!(with_protected_metadata: with_protected_metadata)
    |> enrich(enrich_fields, opts)
  end

  defp do_get_data_structure_version!(data_structure_id, version, enrich_fields, opts) do
    with_protected_metadata = Enum.member?(enrich_fields, :with_protected_metadata)

    DataStructureVersion
    |> Repo.get_by!(data_structure_id: data_structure_id, version: version)
    |> Map.get(:id)
    |> enriched_structure_version!(
      with_protected_metadata: with_protected_metadata,
      preload: @preload_dsv_assocs
    )
    |> enrich(enrich_fields, opts)
  end

  def get_cached_content(%{} = content, %{structure_type: %{template_id: template_id}}) do
    get_cached_content(content, %{data_structure_type: %{template_id: template_id}})
  end

  def get_cached_content(%{} = content, %{data_structure_type: %{template_id: template_id}}) do
    case TemplateCache.get(template_id) do
      {:ok, template} ->
        Format.enrich_content_values(content, template, [:system, :hierarchy])

      _ ->
        content
    end
  end

  def get_cached_content(content, _structure), do: content

  def get_ds_classifications!(%DataStructureVersion{} = dsv) do
    Repo.preload(dsv, :classifications)
    |> case do
      %{classifications: classifications} ->
        Enum.reduce(classifications, %{}, fn %{name: name, class: class}, acc ->
          Map.put(acc, name, class)
        end)

      _ ->
        %{}
    end
  end

  defp enrich_defaults(
         %DataStructureVersion{id: id} = _data_structure_version,
         with_protected_metadata
       ) do
    enriched_structure_version!(id,
      with_protected_metadata: with_protected_metadata,
      preload: [data_structure: :source]
    )
  end

  defp enrich(target, enrich_fields, opts \\ [])

  defp enrich(nil = _target, _enrich_fields, _opts), do: nil

  defp enrich(target, nil = _enrich_fields, _opts), do: target

  defp enrich(%DataStructureVersion{} = dsv, enrich_fields, opts) do
    deleted = not is_nil(Map.get(dsv, :deleted_at))
    with_confidential = Enum.member?(enrich_fields, :with_confidential)
    with_protected_metadata = Enum.member?(enrich_fields, :with_protected_metadata)

    data_fields_opts =
      Keyword.merge(
        [
          deleted: deleted,
          preload:
            if(Enum.member?(enrich_fields, :profile),
              do: [:published_note, data_structure: :profile],
              else: [:published_note]
            ),
          with_confidential: with_confidential,
          with_protected_metadata: with_protected_metadata
        ],
        opts[:data_fields] || []
      )

    dsv
    |> enrich_defaults(with_protected_metadata)
    |> do_enrich(enrich_fields, :classifications, &get_classifications!/1)
    |> do_enrich(enrich_fields, :system, &get_system!/1)
    |> do_enrich(enrich_fields, :parent_relations, &get_parent_relations!/1)
    |> do_enrich(
      enrich_fields,
      :parents,
      &get_parents(
        &1,
        deleted: deleted,
        with_confidential: with_confidential,
        with_protected_metadata: false
      )
    )
    |> do_enrich(
      enrich_fields,
      :children,
      &get_children(
        &1,
        deleted: deleted,
        with_confidential: with_confidential,
        with_protected_metadata: false
      )
    )
    |> do_enrich(
      enrich_fields,
      :siblings,
      &get_siblings(
        &1,
        deleted: deleted,
        with_confidential: with_confidential,
        with_protected_metadata: false
      )
    )
    |> do_enrich(
      enrich_fields,
      :data_fields,
      &get_field_structures(&1, data_fields_opts)
    )
    |> do_enrich(enrich_fields, :data_field_degree, &get_field_degree/1)
    |> do_enrich(enrich_fields, :data_field_links, &get_field_links/1)
    |> do_enrich(
      enrich_fields,
      :relations,
      &get_relations(
        &1,
        deleted: deleted,
        default: false,
        with_confidential: with_confidential,
        with_protected_metadata: with_protected_metadata
      )
    )
    |> do_enrich(enrich_fields, :relation_links, &get_relation_links/1)
    |> do_enrich(enrich_fields, :versions, &get_versions!(&1, with_protected_metadata))
    |> do_enrich(enrich_fields, :degree, &get_degree/1)
    |> do_enrich(enrich_fields, :profile, &get_profile!/1)
    |> do_enrich(enrich_fields, :links, &get_structure_links(&1, opts))
    |> do_enrich(enrich_fields, :data_structure_link_count, &get_data_structure_link_count/1)
    |> do_enrich(enrich_fields, :source, &get_source!/1)
    |> do_enrich(
      enrich_fields,
      :metadata_versions,
      &get_metadata_versions!(
        &1,
        with_protected_metadata: with_protected_metadata
      )
    )
    |> do_enrich(enrich_fields, :data_structure_type, &get_data_structure_type!/1)
    |> do_enrich(enrich_fields, :grants, &get_grants/1)
    |> do_enrich(enrich_fields, :grant, &get_grant(&1, enrich_fields[:user_id]))
    |> do_enrich(enrich_fields, :implementation_count, &get_implementation_count!/1)
    |> do_enrich(enrich_fields, :published_note, &get_published_note!/1)
  end

  defp do_enrich(%{} = target, enrich_fields, key, fun) do
    target_key = get_target_key(key)

    case Enum.member?(enrich_fields, key) do
      false -> target
      true -> Map.put(target, target_key, fun.(target))
    end
  end

  def get_published_note!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, :published_note) do
      %{published_note: published_note} -> published_note
    end
  end

  defp get_target_key(:data_field_degree), do: :data_fields
  defp get_target_key(:data_field_links), do: :data_fields
  defp get_target_key(:relation_links), do: :relations
  defp get_target_key(key), do: key

  def get_system!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, data_structure: :system) do
      %{data_structure: %{system: system}} -> system
    end
  end

  def get_classifications!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, :classifications) do
      %{classifications: classifications} -> classifications
    end
  end

  def get_profile!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, data_structure: :profile) do
      %{data_structure: %{profile: profile}} -> profile
    end
  end

  defp get_parent_relations!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, parent_relations: :parent) do
      %{parent_relations: parent_relations} -> parent_relations
    end
  end

  def get_data_structure_type!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, :structure_type) do
      %{structure_type: structure_type} -> structure_type
    end
  end

  def get_data_structure_type(%DataStructure{current_version: %{structure_type: %{name: type}}}) do
    type
  end

  def get_data_structure_type(_data_structure), do: nil

  def get_field_structures(data_structure_version, opts) do
    data_structure_version
    |> get_field_structures_query(opts)
    |> with_limit(opts[:search])
    |> Repo.all()
    |> enrich_data_fiels(opts)
  end

  def stream_field_structures(data_structure_version, opts \\ []) do
    data_structure_version
    |> get_field_structures_query(opts)
    |> Repo.stream()
  end

  defp get_paginated_field_structures(data_structure_version, opts) do
    search_args = flop_search_args(opts[:search])

    {:ok, {data_fields, meta}} =
      data_structure_version
      |> get_field_structures_query(opts)
      |> subquery()
      |> select([r], r)
      |> Flop.validate_and_run(search_args, for: DataStructureVersion)

    {enrich_data_fiels(data_fields, opts), meta}
  end

  defp get_field_structures_query(data_structure_version, opts) do
    data_structure_version
    |> Ecto.assoc(:children)
    |> where(class: "field")
    |> join(:inner, [child], child_ds in assoc(child, :data_structure), as: :child_ds)
    |> profile_condition(opts[:search])
    |> with_confidential(
      Keyword.get(opts, :with_confidential),
      dynamic([child_ds: child_ds], child_ds.confidential == false)
    )
    |> with_data_structure_domain_ids(opts[:domain_ids])
    |> with_deleted(opts, dynamic([child], is_nil(child.deleted_at)))
    |> select_merge([child], %{
      metadata_order:
        type(
          fragment(
            """
              CASE
                WHEN trim(?->>?) ~ '^\\d+(\\.\\d+){0,1}$' THEN trim(?->>?)::numeric
                ELSE NULL
              END
            """,
            child.metadata,
            "order",
            child.metadata,
            "order"
          ),
          :decimal
        )
    })
  end

  defp profile_condition(query, %{data_fields_filter: %{has_profile: true}}) do
    join(query, :inner, [child_ds: child_ds], profile in assoc(child_ds, :profile), as: :profile)
  end

  defp profile_condition(query, _has_profile), do: query

  defp with_data_structure_domain_ids(query, %{"view_data_structure" => :all}), do: query

  defp with_data_structure_domain_ids(query, %{"view_data_structure" => :none}),
    do: where(query, [], false)

  defp with_data_structure_domain_ids(query, %{"view_data_structure" => domain_ids})
       when is_list(domain_ids) do
    where(query, [child_ds: child_ds], fragment("? && ?", child_ds.domain_ids, ^domain_ids))
  end

  defp with_data_structure_domain_ids(query, _domain_permissions), do: query

  defp flop_search_args(%{} = search_args) do
    search_args
    |> eval_search_query()
    |> Map.drop([:search, :data_fields_filter])
  end

  defp flop_search_args(_search_args), do: %{}

  defp eval_search_query(%{search: search_query} = search_args) when is_binary(search_query) do
    case String.trim(search_query) do
      "" -> search_args
      full_text -> Map.put(search_args, :filters, [%{field: :name, op: :=~, value: full_text}])
    end
  end

  defp eval_search_query(search_args), do: search_args

  defp enrich_data_fiels(data_fields, opts) do
    data_fields
    |> Repo.preload(opts[:preload] || [])
    |> protect_metadata(Keyword.get(opts, :with_protected_metadata))
    |> get_field_links()
    |> get_field_degree()
  end

  def get_mutable_metadata(nil, _), do: []
  def get_mutable_metadata([], _), do: []

  def get_mutable_metadata(dsv, opts) when is_list(dsv) do
    Enum.map(dsv, &get_mutable_metadata(&1, opts))
  end

  def get_mutable_metadata(dsv, opts) do
    metadata_versions = get_metadata_versions!(dsv, opts)
    Map.put(dsv, :metadata_versions, metadata_versions)
  end

  def get_children(%DataStructureVersion{id: id}, opts \\ []) do
    default = Keyword.get(opts, :default)
    deleted = Keyword.get(opts, :deleted)
    confidential = Keyword.get(opts, :with_confidential)
    default_relation_type_id = RelationTypes.default_id!()

    DataStructureRelation
    |> where([r], r.parent_id == ^id)
    |> join(:inner, [r], child in assoc(r, :child), as: :child)
    |> join(:inner, [r], relation_type in assoc(r, :relation_type), as: :relation_type)
    |> join(:inner, [child: child], ds in assoc(child, :data_structure), as: :child_ds)
    |> with_deleted(deleted, dynamic([child: c], is_nil(c.deleted_at)))
    |> with_confidential(confidential, dynamic([child_ds: ds], ds.confidential == false))
    |> relation_type_condition(
      default,
      dynamic([relation_type: rt], rt.id == ^default_relation_type_id),
      dynamic([relation_type: rt], rt.id != ^default_relation_type_id)
    )
    |> order_by([child: c], asc: c.data_structure_id, desc: c.version)
    |> distinct([child: c], c)
    |> select([r, child: c, relation_type: rt], %{
      version: c,
      relation: r,
      relation_type: rt
    })
    |> Repo.all()
    |> select_structures(default)
    |> protect_metadata(Keyword.get(opts, :with_protected_metadata))
  end

  def get_parents(%DataStructureVersion{id: id}, opts \\ []) do
    default = Keyword.get(opts, :default)
    deleted = Keyword.get(opts, :deleted)
    confidential = Keyword.get(opts, :with_confidential)
    default_relation_type_id = RelationTypes.default_id!()

    DataStructureRelation
    |> where([r], r.child_id == ^id)
    |> join(:inner, [r], parent in assoc(r, :parent), as: :parent)
    |> join(:inner, [r], relation_type in assoc(r, :relation_type), as: :relation_type)
    |> join(:inner, [parent: parent], parent_ds in assoc(parent, :data_structure), as: :parent_ds)
    |> with_deleted(deleted, dynamic([parent: parent], is_nil(parent.deleted_at)))
    |> relation_type_condition(
      default,
      dynamic([relation_type: rt], rt.id == ^default_relation_type_id),
      dynamic([relation_type: rt], rt.id != ^default_relation_type_id)
    )
    |> with_confidential(confidential, dynamic([parent_ds: ds], ds.confidential == false))
    |> order_by([parent: p], asc: p.data_structure_id, desc: p.version)
    |> distinct([parent: p], p)
    |> select([r, parent: p, relation_type: rt], %{
      version: p,
      relation: r,
      relation_type: rt
    })
    |> Repo.all()
    |> select_structures(default)
    |> protect_metadata(Keyword.get(opts, :with_protected_metadata))
  end

  def get_siblings(%DataStructureVersion{id: id}, opts \\ []) do
    default_relation_type_id = RelationTypes.default_id!()
    confidential = Keyword.get(opts, :with_confidential)
    default = Keyword.get(opts, :default)
    limit = Keyword.get(opts, :limit)

    DataStructureRelation
    |> where([r], r.child_id == ^id)
    |> join(:inner, [r], parent in assoc(r, :parent), as: :parent)
    |> join(:inner, [r], parent_rt in assoc(r, :relation_type), as: :parent_rt)
    |> join(:inner, [parent: parent], sib_rel in DataStructureRelation,
      as: :sib_rel,
      on: parent.id == sib_rel.parent_id
    )
    |> join(:inner, [sib_rel: r], child_rt in assoc(r, :relation_type), as: :child_rt)
    |> join(:inner, [sib_rel: r], sibling in assoc(r, :child), as: :sibling)
    |> join(:inner, [sibling: s], ds in assoc(s, :data_structure), as: :sibling_ds)
    |> with_deleted(opts, dynamic([parent: p], is_nil(p.deleted_at)))
    |> with_deleted(opts, dynamic([sibling: s], is_nil(s.deleted_at)))
    |> with_confidential(confidential, dynamic([sibling_ds: ds], ds.confidential == false))
    |> relation_type_condition(
      default,
      dynamic([parent_rt: rt], rt.id == ^default_relation_type_id),
      dynamic([parent_rt: rt], rt.id != ^default_relation_type_id)
    )
    |> relation_type_condition(
      default,
      dynamic([child_rt: rt], rt.id == ^default_relation_type_id),
      dynamic([child_rt: rt], rt.id != ^default_relation_type_id)
    )
    |> order_by([sibling: s], asc: s.data_structure_id, desc: s.version)
    |> distinct([sibling: s], s)
    |> select([sibling: s], s)
    |> with_limit(limit)
    |> Repo.all()
    |> Repo.preload(@preload_dsv_assocs)
    |> Enum.uniq_by(& &1.data_structure_id)
    |> protect_metadata(Keyword.get(opts, :with_protected_metadata))
  end

  def siblings({:siblings, batch_key}, data_structure_versions) do
    sibling = batch_key[:add_siblings]

    Map.new(data_structure_versions, fn data_structure_version ->
      {data_structure_version, get_siblings(sibling, batch_key)}
    end)
  end

  def data_fields({:data_fields, batch_key}, data_structure_versions) do
    parent = batch_key[:add_fields]

    Map.new(data_structure_versions, fn data_structure_version ->
      {data_structure_version, get_paginated_field_structures(parent, batch_key)}
    end)
  end

  def get_relations(%DataStructureVersion{} = version, opts) do
    parents = get_parents(version, opts)
    children = get_children(version, opts)

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

  def get_versions!(%DataStructureVersion{} = dsv, with_protected_metadata) do
    case Repo.preload(dsv, data_structure: :versions) do
      %{data_structure: %{versions: versions}} ->
        protect_metadata(versions, with_protected_metadata)
    end
  end

  def get_grants(%DataStructureVersion{data_structure_id: id, path: path}, clauses \\ %{}) do
    ids = Enum.reduce(path, [id], fn %{"data_structure_id" => id}, acc -> [id | acc] end)

    dsv_preloader = &enriched_structure_versions(data_structure_ids: &1)

    clauses
    |> Map.put(:data_structure_ids, ids)
    |> Map.put(:preload, [:system, :data_structure, data_structure_version: dsv_preloader])
    |> Grants.list_active_grants()
    |> Enum.map(fn %{user_id: user_id} = grant ->
      case UserCache.get(user_id) do
        {:ok, %{} = user} -> %{grant | user: user}
        _ -> grant
      end
    end)
    |> Enum.sort_by(& &1.id)
  end

  def get_grant(%DataStructureVersion{} = dsv, user_id) do
    dsv
    |> get_grants(%{user_id: user_id})
    # TODO: This assumes a child's external_id is longer than the parent's external_id
    |> Enum.max_by(&String.length(&1.data_structure.external_id), fn -> nil end)
  end

  defp select_structures(versions, false) do
    versions
    |> Enum.uniq_by(& &1.version.data_structure_id)
    |> Enum.map(&preload_assocs/1)
  end

  defp select_structures(versions, _not_false) do
    versions
    |> Enum.uniq_by(& &1.version.data_structure_id)
    |> Enum.map(fn %{version: version} -> version end)
    |> Repo.preload(@preload_dsv_assocs)
  end

  # These are preloaded as they are needed in views
  defp preload_assocs(%{version: v} = version, preloads \\ @preload_dsv_assocs) do
    Map.put(version, :version, Repo.preload(v, preloads))
  end

  def get_source!(%DataStructureVersion{} = dsv) do
    case Repo.preload(dsv, data_structure: :source) do
      %{data_structure: %{source: source}} -> source
    end
  end

  defp get_metadata_versions!(%DataStructureVersion{} = dsv, opts) do
    with_protected_metadata = Keyword.get(opts, :with_protected_metadata)

    case Repo.preload(dsv, data_structure: :metadata_versions) do
      %{data_structure: %{metadata_versions: metadata_versions}} ->
        protect_metadata(
          metadata_versions,
          with_protected_metadata
        )
    end
  end

  def protect_metadata(dsv_or_sm_or_sm_list_or_map, with_protected_metadata)

  def protect_metadata(nil, _with_protected_metadata), do: nil

  def protect_metadata(dsv_or_sm_or_sm_list_or_map, nil) do
    protect_metadata(dsv_or_sm_or_sm_list_or_map, false)
  end

  def protect_metadata(dsv_or_sm_or_sm_list_or_map, true) do
    dsv_or_sm_or_sm_list_or_map
  end

  def protect_metadata(structuremetadata_or_dsv_with_mutable_metadata, false)
      when is_list(structuremetadata_or_dsv_with_mutable_metadata) do
    Enum.map(structuremetadata_or_dsv_with_mutable_metadata, &protect_metadata(&1, false))
  end

  def protect_metadata(
        %DataStructureVersion{
          metadata: metadata,
          # From DataStructureQueries.enriched_structure_versions
          mutable_metadata: enriched_mm
        } = dsv,
        false
      ) do
    %DataStructureVersion{
      dsv
      | metadata: protect_metadata(metadata, false),
        mutable_metadata: protect_metadata(enriched_mm, false)
    }
  end

  def protect_metadata(%StructureMetadata{fields: fields} = mutable_metadata, false) do
    %StructureMetadata{
      mutable_metadata
      | fields: protect_metadata(fields, false)
    }
  end

  def protect_metadata(metadata, false) do
    Map.drop(metadata, [@protected])
  end

  def get_implementation_count!(%DataStructureVersion{data_structure_id: id}) do
    TdDq.Implementations.ImplementationStructure
    |> where([i], is_nil(i.deleted_at))
    |> where([i], i.data_structure_id == ^id)
    |> select([i], count(i.implementation_id, :distinct))
    |> Repo.one!()
  end

  def update_changeset(%Claims{user_id: user_id}, %DataStructure{} = data_structure, %{} = params) do
    DataStructure.changeset(data_structure, params, user_id)
  end

  def update_data_structure(claims, data_structure, params, inherit) do
    changeset = update_changeset(claims, data_structure, params)
    update_data_structure(claims, changeset, inherit)
  end

  def update_data_structure(claims, changeset, inherit)

  def update_data_structure(_claims, %Changeset{valid?: false} = changeset, _),
    do: {:error, changeset}

  def update_data_structure(_claims, %Changeset{changes: %{} = changes}, _)
      when map_size(changes) == 0,
      do: {:ok, %{}}

  def update_data_structure(
        %Claims{user_id: user_id},
        %Changeset{data: %DataStructure{id: id}} = changeset,
        inherit
      ) do
    id
    |> do_update_data_structure(changeset, inherit, user_id)
    |> maybe_reindex_implementations()
    |> maybe_reindex_grant_requests()
    |> tap(&on_update/1)
  end

  def update_data_structures(%Claims{user_id: user_id}, changesets, inherit)
      when is_list(changesets) do
    changesets
    |> Enum.map(fn {index, %Changeset{data: %DataStructure{id: id}} = changeset} ->
      {index, do_update_data_structure(id, changeset, inherit, user_id)}
    end)
    |> tap(fn results ->
      results
      |> Enum.reduce([], fn
        {_index, {:ok, %{updated_ids: updated_ids}}}, acc ->
          [updated_ids | acc]

        _, acc ->
          acc
      end)
      |> List.flatten()
      |> maybe_reindex_implementations()
      |> maybe_reindex_grant_requests()
      |> on_update
    end)
  end

  defp do_update_data_structure(id, %{changes: changes} = changeset, inherit, user_id) do
    changes
    |> Map.take([:confidential, :domain_ids])
    |> Enum.map(fn
      {key, value} ->
        {key, DataStructureQueries.update_all_query([id], key, value, user_id, inherit)}
    end)
    |> Enum.reduce(Multi.new(), fn
      {key, queryable}, multi -> Multi.update_all(multi, key, queryable, [])
    end)
    |> Multi.run(:updated_ids, &updated_ids/2)
    |> Multi.run(:audit, Audit, :data_structure_updated, [id, changeset, user_id])
    |> Repo.transaction()
  end

  defp updated_ids(_repo, %{} = changes) do
    ids =
      changes
      |> Map.take([:confidential, :domain_ids])
      |> Map.values()
      |> Enum.flat_map(fn {_, ids} -> ids end)
      |> Enum.uniq()

    {:ok, ids}
  end

  defp on_update({:ok, %{updated_ids: ids}}), do: Indexer.reindex(ids)
  defp on_update(ids) when is_list(ids), do: Indexer.reindex(ids)

  defp on_update(_), do: :ok

  defp maybe_reindex_implementations({:ok, %{domain_ids: {_, structures_ids}}} = result) do
    Implementations.reindex_implementations_structures(structures_ids)
    result
  end

  defp maybe_reindex_implementations(structures_ids) when is_list(structures_ids) do
    Implementations.reindex_implementations_structures(structures_ids)
    structures_ids
  end

  defp maybe_reindex_implementations(result), do: result

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
      IndexWorker.delete(@index, data_structure_ids)
    end

    with %{descendents: %{data_structures_ids: structures_ids}} <- res do
      IndexWorker.delete(@index, structures_ids)
    end

    {:ok, res}
  end

  defp on_delete(res), do: res

  def logical_delete_data_structure(
        %DataStructureVersion{data_structure: ds} = data_structure_version,
        %Claims{
          user_id: user_id
        }
      ) do
    now = DateTime.utc_now()

    ds_changeset = DataStructure.changeset_updated_at(ds, user_id)

    Multi.new()
    |> Multi.run(:descendents, fn _, _ -> get_structure_descendents(data_structure_version) end)
    |> Multi.update_all(
      :delete_dsv_descendents,
      fn changes -> delete_dsv_descendents(changes) end,
      set: [deleted_at: now, updated_at: now]
    )
    |> Multi.update_all(
      :delete_metadata_descendents,
      fn changes -> delete_metadata_descendents(changes) end,
      set: [deleted_at: now, updated_at: now]
    )
    |> Multi.update(:update_at_change, ds_changeset)
    |> Multi.run(:audit, Audit, :data_structure_deleted, [user_id])
    |> Repo.transaction()
    |> on_delete()
  end

  def delete_dsv_descendents(%{
        descendents: %{data_structure_version_descendents: descendents_ids}
      }) do
    DataStructureVersion
    |> where([dsv], dsv.id in ^descendents_ids)
  end

  def delete_metadata_descendents(%{descendents: %{data_structures_ids: structures_ids}}) do
    StructureMetadata
    |> where([sm], sm.data_structure_id in ^structures_ids)
    |> where([sm], is_nil(sm.deleted_at))
  end

  def get_structure_descendents(data_structure_version) do
    {data_structure_version_descendents, data_structures_ids} =
      data_structure_version
      |> get_descendents()
      |> List.insert_at(0, data_structure_version)
      |> Enum.map(fn %{id: dsv_id, data_structure_id: ds_id} -> {dsv_id, ds_id} end)
      |> Enum.unzip()

    {:ok,
     %{
       data_structure_version_descendents: data_structure_version_descendents,
       data_structures_ids: data_structures_ids
     }}
  end

  def get_latest_version_details(data_structure_id) do
    DataStructureVersion
    |> where(data_structure_id: ^data_structure_id)
    |> distinct(:data_structure_id)
    |> order_by(desc: :version)
    |> preload(data_structure: :source)
    |> Repo.one()
  end

  def get_data_structure_version_details(data_structure_id, version) do
    DataStructureVersion
    |> preload(data_structure: :source)
    |> Repo.get_by!(data_structure_id: data_structure_id, version: version)
  end

  def get_latest_version(target, enrich_fields \\ [], opts \\ [])

  def get_latest_version(nil, _, _), do: nil

  def get_latest_version(target, [_ | _] = enrich_or_opts, []) do
    if Keyword.keyword?(enrich_or_opts) do
      do_get_latest_version(target, [], enrich_or_opts)
    else
      do_get_latest_version(target, enrich_or_opts, [])
    end
  end

  def get_latest_version(target, enrich_fields, opts),
    do: do_get_latest_version(target, enrich_fields, opts)

  defp do_get_latest_version(%DataStructure{id: id}, enrich_fields, opts) do
    get_latest_version(id, enrich_fields, opts)
  end

  defp do_get_latest_version(data_structure_id, enrich_fields, opts) do
    DataStructureVersion
    |> where(data_structure_id: ^data_structure_id)
    |> distinct(:data_structure_id)
    |> order_by(desc: :version)
    |> preload(data_structure: :source)
    |> Repo.one()
    |> enrich(enrich_fields, opts)
  end

  def find_data_structure(%{} = clauses) do
    Repo.get_by(DataStructure, clauses)
  end

  def get_degree(%{data_structure: %{external_id: external_id}}) do
    get_degree(external_id)
  end

  def get_degree(external_id) when is_binary(external_id) do
    case GraphData.degree(external_id) do
      {:ok, degree} -> degree
      {:error, _} -> nil
    end
  end

  def get_degree(_), do: nil

  defp get_field_degree(%{data_fields: {data_fields, _meta}}) do
    get_field_degree(data_fields)
  end

  defp get_field_degree(%{data_fields: data_fields}) when is_list(data_fields) do
    get_field_degree(data_fields)
  end

  defp get_field_degree(data_fields) when is_list(data_fields) do
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

  defp get_field_links(%{data_fields: {data_fields, _meta}}) do
    get_field_links(data_fields)
  end

  defp get_field_links(%{data_fields: data_fields}) when is_list(data_fields) do
    get_field_links(data_fields)
  end

  defp get_field_links(data_fields) when is_list(data_fields) do
    Enum.map(data_fields, &Map.put(&1, :links, get_structure_links(&1)))
  end

  def get_data_structure_link_count(%{data_structure_id: this_ds_id} = _dsv) do
    DataStructureLinks.link_count(this_ds_id)
  end

  def get_structure_links(data_structure), do: get_structure_links(data_structure, [])

  def get_structure_links(%{data_structure_id: id}, opts) when is_list(opts) do
    case LinkCache.list("data_structure", id, opts) do
      {:ok, links} -> links
    end
  end

  def get_structure_links(data_structure, resource_type) when is_binary(resource_type),
    do: get_structure_links(data_structure, resource_type, [])

  def get_structure_links(%{data_structure_id: id}, resource_type, opts)
      when is_binary(resource_type) do
    case LinkCache.list("data_structure", id, resource_type, opts) do
      {:ok, links} -> links
    end
  end

  ## This function gets the ancestors in reverse order
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

  def get_latest_version_by_external_id(external_id, opts \\ []) do
    DataStructureVersion
    |> with_deleted(opts, dynamic([dsv], is_nil(dsv.deleted_at)))
    |> distinct(:data_structure_id)
    |> order_by(desc: :version)
    |> join(:inner, [data_structure], ds in assoc(data_structure, :data_structure))
    |> where([_, ds], ds.external_id == ^external_id)
    |> select_merge([_, ds], %{external_id: ds.external_id})
    |> Repo.one()
    |> enrich(opts[:enrich])
  end

  @spec get_latest_versions([non_neg_integer]) :: [DataStructureVersion.t()]
  def get_latest_versions(structure_ids) when is_list(structure_ids) do
    DataStructureVersion
    |> distinct(:data_structure_id)
    |> order_by(desc: :version)
    |> where([dsv], dsv.data_structure_id in ^structure_ids)
    |> Repo.all()
  end

  defp with_deleted(query, opts, dynamic) when is_list(opts) do
    include_deleted = Keyword.get(opts, :deleted, true)
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

  defp with_limit(query, limit) when is_integer(limit) do
    limit(query, ^limit)
  end

  defp with_limit(query, %{first: limit}) when is_integer(limit) do
    limit(query, ^limit)
  end

  defp with_limit(query, _limit), do: query

  @doc """
  Returns a Map whose keys are external ids and whose values are data
  structure ids.
  """
  def external_id_map do
    from(ds in DataStructure, select: {ds.external_id, ds.id})
    |> Repo.all()
    |> Map.new()
  end

  def create_structure_metadata(params) do
    %StructureMetadata{}
    |> StructureMetadata.changeset(params)
    |> Repo.insert()
  end

  def get_structure_metadata!(id), do: Repo.get!(StructureMetadata, id)

  def update_structure_metadata(%StructureMetadata{} = structure_metadata, params) do
    structure_metadata
    |> StructureMetadata.changeset(params)
    |> Repo.update()
    |> maybe_reindex_grant_requests()
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
        "(?, COALESCE(?, statement_timestamp())) OVERLAPS (?, COALESCE(?, statement_timestamp()))",
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

  @spec template_name(any) :: any
  def template_name(%StructureNote{data_structure_id: data_structure_id}) do
    data_structure = get_data_structure!(data_structure_id)
    template_name(data_structure)
  end

  def template_name(%DataStructure{} = data_structure) do
    data_structure
    |> get_latest_version()
    |> template_name()
  end

  def template_name(%DataStructureVersion{} = dsv) do
    with %{structure_type: %{template_id: template_id}} when is_integer(template_id) <-
           Repo.preload(dsv, :structure_type),
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
    |> where([sm], is_nil(sm.deleted_at))
    |> order_by(asc: :data_structure_id, desc: :version)
  end

  def profile_source(
        %{
          data_structure: %{source: %{config: %{"job_types" => %{"value" => job_types}}} = source}
        } = dsv
      ) do
    if Enum.member?(job_types, "profile") do
      Map.put(dsv, :profile_source, source)
    else
      do_profile_source(dsv, source)
    end
  end

  def profile_source(dsv), do: dsv

  defp do_profile_source(dsv, %{external_id: external_id}) when is_binary(external_id) do
    sources =
      case Sources.query_sources(%{aliases: external_id, job_types: "profile"}) do
        [_ | _] = sources -> sources
        _ -> Sources.query_sources(%{alias: external_id, job_types: "profile"})
      end

    case sources do
      [%Source{} = source | _] ->
        Map.put(dsv, :profile_source, source)

      _ ->
        dsv
    end
  end

  defp do_profile_source(dsv, _source), do: dsv

  # Returns a data structure version enriched for indexing or rendering
  @spec enriched_structure_version!(binary() | integer(), keyword) ::
          DataStructureVersion.t()
  defp enriched_structure_version!(id, opts \\ [])

  defp enriched_structure_version!(id, opts) when is_binary(id) do
    id
    |> String.to_integer()
    |> enriched_structure_version!(opts)
  end

  defp enriched_structure_version!(id, opts) do
    opts
    |> Keyword.put(:ids, [id])
    |> enriched_structure_versions()
    |> hd()
  end

  @spec enriched_structure_versions(keyword) :: [DataStructureVersion.t()]
  def enriched_structure_versions(opts \\ []) do
    {enrich_opts, opts} = Keyword.split(opts, [:content, :filters])
    enrich = StructureVersionEnricher.enricher(enrich_opts)

    opts
    |> Map.new()
    |> Map.drop([:with_protected_metadata])
    |> DataStructureQueries.enriched_structure_versions()
    |> Repo.all()
    |> Enum.map(
      &(&1
        |> enrich.()
        |> protect_metadata(Keyword.get(opts, :with_protected_metadata)))
    )
  end

  def enriched_structure_version(data_structure_version, opts \\ [])

  def enriched_structure_version(%DataStructureVersion{} = data_structure_version, opts) do
    enrich = StructureVersionEnricher.enricher(opts)
    enrich.(data_structure_version)
  end

  def enriched_structure_version(other, _opts), do: other

  def embeddings([]), do: {:ok, []}

  def embeddings(data_structure_versions) when is_list(data_structure_versions) do
    data_structure_versions
    |> Enum.map(&embedding_attributes/1)
    |> Embeddings.all()
  end

  def generate_vector(_version_or_id, collection_name \\ nil)

  def generate_vector(
        %DataStructureVersion{record_embeddings: [%RecordEmbedding{} = record]},
        _collection_name
      ) do
    {record.collection, record.embedding}
  end

  def generate_vector(%DataStructureVersion{} = version, collection_name) do
    version
    |> embedding_attributes()
    |> Embeddings.generate_vector(collection_name)
    |> tap(fn {:ok, _vector} ->
      RecordEmbeddings.upsert_from_structures_async(version.data_structure_id)
    end)
    |> then(fn {:ok, vector} -> vector end)
  end

  def generate_vector(nil, _collection_name), do: nil

  def generate_vector(id, collection_name) do
    collection_name = collection_name_or_default(collection_name)
    preload = [record_embeddings: where(RecordEmbedding, [re], re.collection == ^collection_name)]

    DataStructureVersion
    |> where([dsv], dsv.data_structure_id == ^id)
    |> where([dsv], is_nil(dsv.deleted_at))
    |> DataStructureQueries.enriched_structure_notes()
    |> preload(^preload)
    |> Repo.one()
    |> enriched_structure_version(content: :searchable)
    |> generate_vector(collection_name)
  end

  def streamed_enriched_structure_versions(opts \\ []) do
    chunk_size = Keyword.get(opts, :chunk_size, 1000)

    {enrich_opts, opts} =
      opts
      |> Keyword.drop([:chunk_size])
      |> Keyword.split([:content, :filters])

    enrich = StructureVersionEnricher.enricher(enrich_opts)

    opts
    |> Map.new()
    |> Map.drop([:with_protected_metadata])
    |> DataStructureQueries.enriched_structure_versions()
    |> Repo.stream()
    |> Stream.chunk_every(chunk_size)
    |> Stream.flat_map(
      &(&1
        |> Enum.map(fn dsv ->
          dsv
          |> enrich.()
          |> protect_metadata(Keyword.get(opts, :with_protected_metadata))
        end))
    )
  end

  def maybe_reindex_grant_requests(
        {:ok,
         %{
           data_structure_id: data_structure_id
         }} = data
      ) do
    Requests.reindex_on_data_structure_update(data_structure_id)

    data
  end

  def maybe_reindex_grant_requests(
        {:ok,
         %{
           updated_ids: data_structure_ids
         }} = data
      ) do
    Requests.reindex_on_data_structure_update(data_structure_ids)

    data
  end

  def maybe_reindex_grant_requests(
        {:ok,
         %{
           structure_note: %{
             data_structure_id: data_structure_id
           }
         }} = data
      ) do
    Requests.reindex_on_data_structure_update(data_structure_id)

    data
  end

  def maybe_reindex_grant_requests(data_structure_ids) when is_list(data_structure_ids) do
    Requests.reindex_on_data_structure_update(data_structure_ids)
    data_structure_ids
  end

  def maybe_reindex_grant_requests(data), do: data

  ## Dataloader
  def datasource do
    timeout = Application.get_env(:td_dd, TdDd.Repo)[:timeout]
    Dataloader.Ecto.new(TdDd.Repo, query: &query/2, timeout: timeout)
  end

  defp query(queryable, params) do
    Enum.reduce(params, queryable, fn
      {:deleted, false}, q -> where(q, [dsv], is_nil(dsv.deleted_at))
      {:deleted, true}, q -> where(q, [dsv], not is_nil(dsv.deleted_at))
      {:add_children, parent}, q -> add_children(q, parent)
      {:add_parents, child}, q -> add_parents(q, child)
      {:preload, preload}, q -> preload(q, ^preload)
      {:limit, limit}, q -> limit(q, ^limit)
    end)
  end

  defp add_children(q, %{id: parent_id}) do
    default_type = RelationTypes.default_id!()

    q
    |> join(:inner, [dsv], r in DataStructureRelation,
      on: r.child_id == dsv.id and r.parent_id == ^parent_id
    )
    |> where([_dsv, r], r.relation_type_id == ^default_type)
  end

  defp add_parents(q, %{id: child_id}) do
    default_type = RelationTypes.default_id!()

    q
    |> join(:inner, [dsv], r in DataStructureRelation,
      on: r.parent_id == dsv.id and r.child_id == ^child_id
    )
    |> where([_dsv, r], r.relation_type_id == ^default_type)
  end

  defp embedding_attributes(%{
         data_structure: %{domains: domains} = data_structure,
         type: type,
         name: name,
         description: description
       }) do
    domain_external_id = domains |> List.wrap() |> hd() |> Map.get(:external_id, "")
    alias_name = alias_name(data_structure)

    String.trim(
      "#{name} #{alias_name} #{type} #{domain_external_id} #{description}" <>
        " " <> links(data_structure)
    )
  end

  defp alias_name(%{search_content: %{"alias" => %{"value" => alias_name}}})
       when is_binary(alias_name),
       do: alias_name

  defp alias_name(_other), do: ""

  defp links(%{id: id}) do
    {:ok, links} = LinkCache.list_rand_links("data_structure", id, "business_concept")
    Enum.map_join(links, " ", &link_embedding/1)
  end

  defp link_embedding(link) do
    "#{Map.get(link, :name)} #{Map.get(link, :type, "")} #{get_in(link, [:domain, :external_id]) || ""}"
  end

  defp collection_name_or_default(collection_name) when is_binary(collection_name),
    do: collection_name

  defp collection_name_or_default(nil) do
    {:ok, %{collection_name: collection_name}} = Indices.first_enabled()
    collection_name
  end
end
