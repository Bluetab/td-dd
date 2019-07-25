defmodule TdDd.Repo.Migrations.DeleteDuplicateDataStructureVersions do
  use Ecto.Migration

  import Ecto.Query
  alias TdDd.Repo
  require Logger

  def change do
    from(dsv in "data_structure_versions")
    |> group_by([dsv], [dsv.data_structure_id, dsv.version])
    |> having([dsv], count(dsv.id) > 1)
    |> select([g], {g.data_structure_id, g.version})
    |> Repo.all()
    |> Enum.flat_map(&get_duplicate_ids/1)
    |> delete_data_structure_versions
  end

  defp get_duplicate_ids({data_structure_id, version}) do
    from(dsv in "data_structure_versions")
    |> where([dsv], dsv.data_structure_id == ^data_structure_id)
    |> where([dsv], dsv.version == ^version)
    |> order_by([dsv], desc: dsv.updated_at, asc: dsv.id)
    |> select([dsv], dsv.id)
    |> Repo.all()
    |> tl
  end

  defp delete_data_structure_versions(ids) do
    from(dsv in "data_structure_versions")
    |> where([dsv], dsv.id in ^ids)
    |> select([dsv], dsv.id)
    |> Repo.delete_all()
  end
end
