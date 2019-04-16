defmodule TdDd.Repo.Migrations.DeleteDuplicateStructuresBySystemIdExternalId do
  use Ecto.Migration

  alias TdDd.DataStructures.DataField
  alias TdDd.Repo

  def change do
    DataField
    |> Repo.all()
    |> Repo.preload(data_structure_versions: [:data_structure])
    |> Enum.map(&with_structure_id(&1))
    |> Enum.group_by(&{&1.data_structure_id, &1.name})
    |> Enum.filter(fn {_, dss} -> Enum.count(dss) > 1 end)
    |> Enum.flat_map(fn {_, [_h | t]} -> t end)
    |> Enum.map(&Repo.delete/1)
  end

  defp with_structure_id( %{
    data_structure_versions: [ %{
      data_structure_id: data_structure_id
    } | _]} = field
  ) do
    Map.put(field, :data_structure_id, data_structure_id)
  end
end
