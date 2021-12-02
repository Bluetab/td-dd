defmodule TdDd.DataStructures.Hierarchy do
  @moduledoc """
  Ecto Schema and utils module for Data Structures Hierarchy.
  """
  use Ecto.Schema
  import Ecto.Query

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Hierarchy
  alias TdDd.Repo

  @primary_key false
  schema "data_structures_hierarchy" do
    field(:ancestor_level, :integer)
    belongs_to(:ds, DataStructure)
    belongs_to(:dsv, DataStructureVersion)
    belongs_to(:ancestor_ds, DataStructure)
    belongs_to(:ancestor_dsv, DataStructureVersion)
  end

  @query """
  SELECT * FROM
  (
  (
  WITH recursive data_structures_hierarchy as (
    SELECT id as dsv_id, data_structure_id as ds_id, id as ancestor_dsv_id, data_structure_id as ancestor_ds_id, 0 as ancestor_level
    FROM data_structure_versions
    where id = ANY (?)
    UNION (
      SELECT dsv_id, ds_id, dsv.id, dsv.data_structure_id, ancestor_level + 1
      FROM data_structures_hierarchy dsh
      JOIN data_structure_relations dsr on dsr.child_id = dsh.ancestor_dsv_id
      JOIN relation_types AS rt ON rt.id = dsr.relation_type_id AND rt.name = 'default'
      JOIN data_structure_versions dsv on dsv.id = dsr.parent_id
    )
  )
  SELECT * FROM data_structures_hierarchy
  )
  UNION
  (
  WITH recursive data_structures_hierarchy as (
    SELECT id as dsv_id, data_structure_id as ds_id, id as ancestor_dsv_id, data_structure_id as ancestor_ds_id, 0 as ancestor_level
    FROM data_structure_versions
    where id = ANY (?)
    UNION (
      SELECT dsv.id, dsv.data_structure_id, ancestor_dsv_id, ancestor_ds_id, ancestor_level + 1
      FROM data_structures_hierarchy dsh
      JOIN data_structure_relations dsr on dsr.parent_id = dsh.dsv_id
      JOIN relation_types AS rt ON rt.id = dsr.relation_type_id AND rt.name = 'default'
      JOIN data_structure_versions dsv on dsv.id = dsr.child_id
    )
  )
  SELECT * FROM data_structures_hierarchy
  )
  ) AS SUBQ
  """

  def update_hierarchy(dsv_ids) do
    name = "hierarchy"

    query =
      name
      |> select([h], %{
        dsv_id: h.dsv_id,
        ds_id: h.ds_id,
        ancestor_dsv_id: h.ancestor_dsv_id,
        ancestor_ds_id: h.ancestor_ds_id,
        ancestor_level: h.ancestor_level
      })
      |> with_cte(^name, as: fragment(@query, ^dsv_ids, ^dsv_ids))

    Repo.insert_all(Hierarchy, query, on_conflict: :nothing)
  end

  def list_hierarchy do
    Repo.all(Hierarchy)
  end
end
