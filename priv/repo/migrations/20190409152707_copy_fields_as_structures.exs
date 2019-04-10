defmodule TdDd.Repo.Migrations.CopyFieldsAsStructures do
  use Ecto.Migration

  import Ecto.Query
  alias TdDd.DataStructures.DataField
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.Loader.FieldsAsStructures
  alias TdDd.Repo

  @ds_props [:domain_id, :group, :ou, :name, :external_id, :system_id, :confidential]
  @df_props [:description, :last_change_at, :last_change_by, :name, :type, :metadata]

  def up do
    fields =
      DataField
      |> Repo.all()
      |> Repo.preload(data_structure_versions: [:data_structure])
      |> Enum.map(&FieldsAsStructures.lift_metadata/1)

    fields_as_structures =
      fields
      |> Enum.flat_map(&field_as_structure_attrs/1)

    structures =
      fields_as_structures
      |> Enum.map(&DataStructure.changeset(%DataStructure{}, &1))
      |> Enum.map(&Repo.insert!/1)

    structure_ids =
      structures
      |> Enum.map(& &1.id)

    versions =
      fields_as_structures
      |> Enum.zip(structure_ids)
      |> Enum.map(fn {m, structure_id} -> Map.put(m, :data_structure_id, structure_id) end)
      |> Enum.map(&DataStructureVersion.changeset(%DataStructureVersion{}, &1))
      |> Enum.map(&Repo.insert!/1)

    version_ids =
      versions
      |> Enum.map(& &1.id)

    _relations =
      fields_as_structures
      |> Enum.zip(version_ids)
      |> Enum.map(fn {m, version_id} -> Map.put(m, :child_id, version_id) end)
      |> Enum.map(&DataStructureRelation.changeset(%DataStructureRelation{}, &1))
  end

  def down do
    from(ds in DataStructure, where: ds.class == "field")
    |> Repo.delete_all()
  end

  defp field_as_structure_attrs(%DataField{data_structure_versions: dsvs, name: name} = field) do
    dsvs
    |> Enum.map(&{&1.data_structure, &1.version, &1.id})
    |> Enum.map(fn {ds, v, parent_id} ->
      Map.take(ds, @ds_props)
      |> Map.put(:version, v)
      |> Map.put(:parent_id, parent_id)
      |> Map.put(:class, "field")
    end)
    |> Enum.map(&with_external_id(&1, name))
    |> Enum.map(&Map.merge(&1, Map.take(field, @df_props)))
  end

  defp with_external_id(%{external_id: nil, name: name} = attrs, field_name) do
    attrs
    |> Map.put(:external_id, name <> "/" <> field_name)
  end

  defp with_external_id(%{external_id: external_id} = attrs, field_name) do
    attrs
    |> Map.put(:external_id, external_id <> "/" <> field_name)
  end
end
