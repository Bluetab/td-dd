defmodule TdDd.DataStructures.Tags do
  @moduledoc """
  The data structures tags context. Provides functions for managing the tags
  associated with data structures.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructuresTags
  alias TdDd.DataStructures.DataStructureTag
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Hierarchy
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker

  def list_available_tags(%DataStructure{domain_ids: domain_ids}) do
    domain_ids = TaxonomyCache.reaching_domain_ids(domain_ids)
    list_data_structure_tags(domain_ids: domain_ids)
  end

  def list_data_structure_tags(params \\ %{}) do
    params
    |> data_structure_tags_query()
    |> Repo.all()
  end

  def get_data_structure_tag(params) do
    params
    |> data_structure_tags_query()
    |> Repo.one()
  end

  def get_data_structure_tag!(params) do
    params
    |> data_structure_tags_query()
    |> Repo.one!()
  end

  def create_data_structure_tag(attrs \\ %{}) do
    %DataStructureTag{}
    |> DataStructureTag.changeset(attrs)
    |> Repo.insert()
  end

  def update_data_structure_tag(%DataStructureTag{} = data_structure_tag, %{} = params) do
    %{changes: changes} =
      changeset =
      data_structure_tag
      |> Repo.preload(:structures_tags)
      |> DataStructureTag.changeset(params)

    reindex = Map.has_key?(changes, :name) or Map.has_key?(changes, :inherit)

    changeset
    |> Repo.update()
    |> maybe_reindex_tagged_structures(reindex)
  end

  def delete_data_structure_tag(%DataStructureTag{} = data_structure_tag) do
    data_structure_tag
    |> Repo.preload(:structures_tags)
    |> Repo.delete()
    |> maybe_reindex_tagged_structures()
  end

  def data_structure_tags_query(params) do
    params
    |> Enum.reduce(DataStructureTag, fn
      {:id, id}, q ->
        where(q, [t], t.id == ^id)

      {:domain_ids, []}, q ->
        where(q, [t], fragment("? = '{}'", t.domain_ids))

      {:domain_ids, domain_ids}, q ->
        where(q, [t], fragment("(? = '{}' OR ? && ?)", t.domain_ids, t.domain_ids, ^domain_ids))

      {:structure_count, true}, q ->
        sq =
          DataStructuresTags
          |> group_by(:data_structure_tag_id)
          |> select([g], %{
            id: g.data_structure_tag_id,
            count: count(g.data_structure_id)
          })

        q
        |> join(:left, [t], c in subquery(sq), on: c.id == t.id)
        |> select_merge([t, c], %{structure_count: fragment("coalesce(?, 0)", c.count)})
    end)
  end

  def tags(%DataStructureVersion{data_structure_id: id}), do: tags(id)

  def tags(%DataStructure{id: id}), do: tags(id)

  def tags(data_structure_id) when is_integer(data_structure_id) do
    DataStructuresTags
    |> join(:inner, [st], h in Hierarchy,
      on:
        st.data_structure_id == h.ds_id or
          (st.inherit and st.data_structure_id == h.ancestor_ds_id)
    )
    |> where([_, h], h.ds_id == ^data_structure_id)
    |> order_by([st, h], asc: st.data_structure_tag_id, asc: h.ds_id, asc: h.ancestor_level)
    |> distinct([st, h], asc: st.data_structure_tag_id, asc: h.ds_id)
    |> preload([:data_structure, :data_structure_tag])
    |> Repo.all()
  end

  def link_tag(
        %DataStructure{id: data_structure_id} = data_structure,
        %DataStructureTag{id: tag_id} = data_structure_tag,
        params,
        claims
      ) do
    case get_link_tag_by(data_structure_id, tag_id) do
      nil -> create_link(data_structure, data_structure_tag, params, claims)
      %DataStructuresTags{} = tag_link -> update_link(tag_link, params, claims)
    end
  end

  def delete_link_tag(
        %DataStructure{id: data_structure_id} = structure,
        %DataStructureTag{id: tag_id},
        %{user_id: user_id} = _claims
      ) do
    case get_link_tag_by(data_structure_id, tag_id) do
      nil ->
        {:error, :not_found}

      %DataStructuresTags{} = tag_link ->
        Multi.new()
        |> Multi.run(:latest, fn _, _ ->
          {:ok, DataStructures.get_latest_version(structure, [:path])}
        end)
        |> Multi.delete(:deleted_link_tag, tag_link)
        |> Multi.run(:audit, Audit, :tag_link_deleted, [user_id])
        |> Repo.transaction()
        |> maybe_reindex_tagged_structures()
    end
  end

  defp get_link_tag_by(data_structure_id, tag_id) do
    DataStructuresTags
    |> Repo.get_by(
      data_structure_tag_id: tag_id,
      data_structure_id: data_structure_id
    )
    |> Repo.preload([:data_structure, :data_structure_tag])
  end

  defp create_link(
         %DataStructure{id: data_structure_id} = data_structure,
         %DataStructureTag{id: tag_id} = data_structure_tag,
         params,
         %{user_id: user_id} = _claims
       ) do
    changeset =
      DataStructuresTags.changeset(
        %DataStructuresTags{
          data_structure_tag: data_structure_tag,
          data_structure_tag_id: tag_id,
          data_structure_id: data_structure_id,
          data_structure: data_structure
        },
        params
      )

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path])}
    end)
    |> Multi.insert(:linked_tag, changeset)
    |> Multi.run(:audit, Audit, :tag_linked, [user_id])
    |> Repo.transaction()
    |> maybe_reindex_tagged_structures()
  end

  defp update_link(%DataStructuresTags{} = link, params, %{user_id: user_id} = _claims) do
    link = Repo.preload(link, [:data_structure_tag, :data_structure])
    %{changes: changes} = changeset = DataStructuresTags.changeset(link, params)

    reindex = Map.has_key?(changes, :name) or Map.has_key?(changes, :inherit)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(link.data_structure, [:path])}
    end)
    |> Multi.update(:linked_tag, changeset)
    |> Multi.run(:audit, Audit, :tag_link_updated, [changeset, user_id])
    |> Repo.transaction()
    |> maybe_reindex_tagged_structures(reindex)
  end

  defp maybe_reindex_tagged_structures(res, reindex \\ true)

  defp maybe_reindex_tagged_structures(
         {:ok, %{structures_tags: [_ | _] = structure_tags} = tag},
         true
       ) do
    structure_tags
    |> Enum.group_by(& &1.inherit, & &1.data_structure_id)
    |> Enum.flat_map(fn {inherit, ids} -> tagged_structure_ids(ids, inherit) end)
    |> Enum.uniq()
    |> IndexWorker.reindex()

    {:ok, tag}
  end

  defp maybe_reindex_tagged_structures({:ok, %{linked_tag: link} = multi}, true) do
    link
    |> tagged_structure_ids()
    |> IndexWorker.reindex()

    {:ok, multi}
  end

  defp maybe_reindex_tagged_structures({:ok, %{deleted_link_tag: link} = multi}, _true) do
    link
    |> tagged_structure_ids()
    |> IndexWorker.reindex()

    {:ok, multi}
  end

  defp maybe_reindex_tagged_structures(res, _), do: res

  defp tagged_structure_ids(%DataStructuresTags{data_structure_id: id, inherit: inherit}) do
    tagged_structure_ids([id], inherit)
  end

  defp tagged_structure_ids(data_structure_ids, true) do
    Hierarchy
    |> where([h], h.ancestor_ds_id in ^data_structure_ids)
    |> select([h], h.ds_id)
    |> Repo.all()
  end

  defp tagged_structure_ids(data_structure_ids, false), do: data_structure_ids
end
