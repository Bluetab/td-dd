defmodule TdDd.DataStructures.Tags do
  @moduledoc """
  The data structures tags context. Provides functions for managing the tags
  associated with data structures.
  """

  import Ecto.Query

  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructuresTags
  alias TdDd.DataStructures.DataStructureTag
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
    |> on_tag_update()
  end

  def delete_data_structure_tag(%DataStructureTag{} = data_structure_tag) do
    data_structure_tag
    |> Repo.preload(:tagged_structures)
    |> Repo.delete()
    |> on_tag_delete()
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

  defp on_tag_update({:ok, %{tagged_structures: [_ | _] = structures} = tag}) do
    structures
    |> Enum.map(& &1.id)
    |> IndexWorker.reindex()

    {:ok, tag}
  end

  defp on_tag_update(reply), do: reply

  defp on_tag_delete({:ok, %{tagged_structures: [_ | _] = structures} = tag}) do
    structures
    |> Enum.map(& &1.id)
    |> IndexWorker.reindex()

    {:ok, tag}
  end

  defp on_tag_delete(reply), do: reply
end
