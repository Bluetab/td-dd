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
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.Search.Indexer
  alias TdDd.DataStructures.Tags.StructureTag
  alias TdDd.DataStructures.Tags.Tag
  alias TdDd.Repo

  defdelegate authorize(action, user, params), to: TdDd.DataStructures.Tags.Policy

  def list_available_tags(%DataStructure{domain_ids: domain_ids}) do
    domain_ids = TaxonomyCache.reaching_domain_ids(domain_ids)
    list_tags(domain_ids: domain_ids)
  end

  def list_tags(params \\ %{}) do
    params
    |> tags_query()
    |> Repo.all()
  end

  def get_tag(params) do
    params
    |> tags_query()
    |> Repo.one()
  end

  def get_tag!(params) do
    params
    |> tags_query()
    |> Repo.one!()
  end

  def create_tag(params \\ %{}) do
    %Tag{}
    |> Tag.changeset(params)
    |> Repo.insert()
  end

  def update_tag(%Tag{} = tag, %{} = params) do
    %{changes: changes} =
      changeset =
      tag
      |> Repo.preload(:structures_tags)
      |> Tag.changeset(params)

    reindex = Map.has_key?(changes, :name) or Map.has_key?(changes, :inherit)

    changeset
    |> Repo.update()
    |> maybe_reindex(reindex)
  end

  def delete_tag(%Tag{} = tag) do
    tag
    |> Repo.preload(:structures_tags)
    |> Repo.delete()
    |> maybe_reindex(true)
  end

  def tags_query(params) do
    params
    |> Enum.reduce(Tag, fn
      {:id, id}, q ->
        where(q, [t], t.id == ^id)

      {:domain_ids, []}, q ->
        where(q, [t], fragment("? = '{}'", t.domain_ids))

      {:domain_ids, domain_ids}, q ->
        where(q, [t], fragment("(? = '{}' OR ? && ?)", t.domain_ids, t.domain_ids, ^domain_ids))

      {:structure_count, true}, q ->
        sq =
          StructureTag
          |> group_by(:tag_id)
          |> select([g], %{
            id: g.tag_id,
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
    StructureTag
    |> join(:inner, [st], h in Hierarchy,
      on:
        st.data_structure_id == h.ds_id or
          (st.inherit and st.data_structure_id == h.ancestor_ds_id)
    )
    |> where([_, h], h.ds_id == ^data_structure_id)
    |> select_merge([st, h], %{inherited: st.data_structure_id != h.ds_id})
    |> order_by([st, h], asc: st.tag_id, asc: h.ds_id, asc: h.ancestor_level)
    |> distinct([st, h], asc: st.tag_id, asc: h.ds_id)
    |> preload([:data_structure, :tag])
    |> Repo.all()
  end

  def tag_structure(
        %DataStructure{id: data_structure_id} = data_structure,
        %Tag{id: tag_id} = tag,
        params,
        claims
      ) do
    case get_current_tag(data_structure_id, tag_id) do
      nil -> create_structure_tag(data_structure, tag, params, claims)
      %StructureTag{} = structure_tag -> update_structure_tag(structure_tag, params, claims)
    end
  end

  def untag_structure(
        %DataStructure{id: data_structure_id} = structure,
        %Tag{id: tag_id},
        %{user_id: user_id} = _claims
      ) do
    case get_current_tag(data_structure_id, tag_id) do
      nil ->
        {:error, :not_found}

      %StructureTag{} = structure_tag ->
        Multi.new()
        |> Multi.run(:latest, fn _, _ ->
          {:ok, DataStructures.get_latest_version(structure, [:path])}
        end)
        |> Multi.delete(:structure_tag, structure_tag)
        |> Multi.run(:audit, Audit, :structure_tag_deleted, [user_id])
        |> Repo.transaction()
        |> maybe_reindex()
    end
  end

  def get_structure_tag(id) do
    StructureTag
    |> Repo.get(id)
    |> Repo.preload([:data_structure, :tag])
  end

  defp get_current_tag(data_structure_id, tag_id) do
    StructureTag
    |> Repo.get_by(
      tag_id: tag_id,
      data_structure_id: data_structure_id
    )
    |> Repo.preload([:data_structure, :tag])
  end

  defp create_structure_tag(
         %DataStructure{id: data_structure_id} = data_structure,
         %Tag{id: tag_id} = tag,
         params,
         %{user_id: user_id} = _claims
       ) do
    changeset =
      StructureTag.changeset(
        %StructureTag{
          tag: tag,
          tag_id: tag_id,
          data_structure_id: data_structure_id,
          data_structure: data_structure
        },
        params
      )

    ds_changeset = DataStructure.changeset_updated_at(data_structure, user_id)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path])}
    end)
    |> Multi.insert(:structure_tag, changeset)
    |> Multi.update(:update_at_change, ds_changeset)
    |> Multi.run(:audit, Audit, :structure_tag_created, [user_id])
    |> Repo.transaction()
    |> maybe_reindex()
  end

  defp update_structure_tag(
         %StructureTag{data_structure: structure} = structure_tag,
         params,
         %{user_id: user_id} = _claims
       ) do
    structure_tag = Repo.preload(structure_tag, [:tag, :data_structure])
    %{changes: changes} = changeset = StructureTag.changeset(structure_tag, params)

    ds_changeset = DataStructure.changeset_updated_at(structure, user_id)

    reindex = Map.has_key?(changes, :name) or Map.has_key?(changes, :inherit)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(structure_tag.data_structure, [:path])}
    end)
    |> Multi.update(:structure_tag, changeset)
    |> Multi.update(:update_at_change, ds_changeset)
    |> Multi.run(:audit, Audit, :structure_tag_updated, [changeset, user_id])
    |> Repo.transaction()
    |> maybe_reindex(reindex)
  end

  def delete_structure_tag(
        %StructureTag{data_structure: structure} = structure_tag,
        %{user_id: user_id} = _claims
      ) do
    ds_changeset = DataStructure.changeset_updated_at(structure, user_id)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(structure, [:path])}
    end)
    |> Multi.delete(:structure_tag, structure_tag)
    |> Multi.update(:update_at_change, ds_changeset)
    |> Multi.run(:audit, Audit, :structure_tag_deleted, [user_id])
    |> Repo.transaction()
    |> maybe_reindex()
  end

  defp maybe_reindex(res, reindex \\ true)

  defp maybe_reindex(
         {:ok, %{structures_tags: [_ | _] = structure_tags} = tag},
         true
       ) do
    ids =
      structure_tags
      |> Enum.group_by(& &1.inherit, & &1.data_structure_id)
      |> Enum.flat_map(fn {inherit, ids} -> tagged_structure_ids(ids, inherit) end)
      |> Enum.uniq()

    Indexer.reindex(ids)

    {:ok, tag}
  end

  defp maybe_reindex({:ok, %{structure_tag: structure_tag} = multi}, true) do
    ids = tagged_structure_ids(structure_tag)

    Indexer.reindex(ids)

    {:ok, multi}
  end

  defp maybe_reindex(res, _), do: res

  defp tagged_structure_ids(%StructureTag{data_structure_id: id, inherit: inherit}) do
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
