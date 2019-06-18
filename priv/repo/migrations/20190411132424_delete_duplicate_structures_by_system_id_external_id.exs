defmodule TdDd.Repo.Migrations.DeleteDuplicateStructuresBySystemIdExternalId do
  use Ecto.Migration

  alias TdDd.DataStructures.DataStructure
  alias TdDd.Repo

  def change do
    DataStructure
    |> Repo.all()
    |> Enum.filter(&(not is_nil(&1.external_id)))
    |> Enum.group_by(&{&1.system_id, &1.external_id})
    |> Enum.filter(fn {_, dss} -> Enum.count(dss) > 1 end)
    |> Enum.flat_map(fn {_, [_h | t]} -> t end)
    |> Enum.map(&Repo.delete/1)
  end
end
