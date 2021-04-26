defmodule TdDd.Repo.Migrations.DeleteDuplicateStructuresBySystemIdExternalId do
  use Ecto.Migration

  import Ecto.Query
  alias TdDd.Repo

  def change do
    from(ds in "data_structures")
    |> select([ds], %{id: ds.id, external_id: ds.external_id, system_id: ds.system_id})
    |> Repo.all()
    |> Enum.filter(&(not is_nil(&1.external_id)))
    |> Enum.group_by(&{&1.system_id, &1.external_id})
    |> Enum.filter(fn {_, dss} -> Enum.count(dss) > 1 end)
    |> Enum.flat_map(fn {_, [_h | t]} -> t end)
    |> Enum.map(&delete_structure/1)
  end

  defp delete_structure(%{id: id}) do
    from(ds in "data_structures")
    |> where([ds], ds.id == ^id)
    |> Repo.delete_all()
  end
end
