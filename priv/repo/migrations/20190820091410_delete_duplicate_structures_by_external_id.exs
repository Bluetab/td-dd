defmodule TdDd.Repo.Migrations.DeleteDuplicateStructuresByExternalId do

  use Ecto.Migration

  import Ecto.Query

  alias TdDd.Repo

  def change do
    from(ds in "data_structures")
    |> where([ds], not is_nil(ds.external_id))
    |> group_by([ds], ds.external_id)
    |> having([ds], count(ds.id) > 1)
    |> select([g], g.external_id)
    |> Repo.all()
    |> Enum.flat_map(&get_duplicate_ids/1)
    |> delete_data_structures
  end

  defp get_duplicate_ids(external_id) do
    from(ds in "data_structures")
    |> where([ds], ds.external_id == ^external_id)
    |> order_by([ds], desc: ds.updated_at, asc: ds.id)
    |> select([ds], ds.id)
    |> Repo.all()
    |> tl
  end

  defp delete_data_structures(ids) do
    from(ds in "data_structures")
    |> where([ds], ds.id in ^ids)
    |> select([ds], ds.id)
    |> Repo.delete_all()
  end
end
