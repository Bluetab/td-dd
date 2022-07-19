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
    data_structure_tag
    |> Repo.preload(:tagged_structures)
    |> DataStructureTag.changeset(params)
    |> Repo.update()
    |> reindex_tagged_structures()
  end

  def delete_data_structure_tag(%DataStructureTag{} = data_structure_tag) do
    data_structure_tag
    |> Repo.preload(:tagged_structures)
    |> Repo.delete()
    |> reindex_tagged_structures()
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
    |> distinct([st, h], asc: st.data_structure_tag_id, asc: h.ds_id, asc: h.ancestor_level)
    |> preload([:data_structure, :data_structure_tag])
    |> Repo.all()
  end

  def get_links_tag(%DataStructure{} = data_structure) do
    # TODO: Replace with tags/1
    data_structure
    |> Ecto.assoc(:data_structures_tags)
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
        |> on_link_delete()
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
    |> on_link_insert()
  end

  defp update_link(%DataStructuresTags{} = link, params, %{user_id: user_id} = _claims) do
    link = Repo.preload(link, [:data_structure_tag, :data_structure])
    changeset = DataStructuresTags.changeset(link, params)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(link.data_structure, [:path])}
    end)
    |> Multi.update(:linked_tag, changeset)
    |> Multi.run(:audit, Audit, :tag_link_updated, [changeset, user_id])
    |> Repo.transaction()
  end

  defp reindex_tagged_structures({:ok, %{tagged_structures: [_ | _] = structures} = tag}) do
    # TODO: reindex descendents if inherited
    structures
    |> Enum.map(& &1.id)
    |> IndexWorker.reindex()

    {:ok, tag}
  end

  defp reindex_tagged_structures(reply), do: reply

  defp on_link_insert({:ok, %{linked_tag: link} = multi}) do
    # TODO: reindex descendents if inherited
    IndexWorker.reindex(link.data_structure_id)
    {:ok, multi}
  end

  defp on_link_insert(reply), do: reply

  defp on_link_delete({:ok, %{deleted_link_tag: link} = multi}) do
    # TODO: reindex descendents if inherited
    IndexWorker.reindex(link.data_structure_id)
    {:ok, multi}
  end

  defp on_link_delete(reply), do: reply
end
