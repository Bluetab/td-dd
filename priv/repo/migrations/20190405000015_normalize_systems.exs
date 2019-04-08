defmodule TdDd.Repo.Migrations.NormalizeSystems do
  use Ecto.Migration
  import Ecto.Query
  alias TdDd.Repo

  def up do
    update_system(nil, "unknown")
    update_system("Azure Data Lake Storage Gen1", "Azure Data Lake Storage")
    update_system("DWH Azure SQL Database", "Azure SQL Database")
    update_system("PowerBI", "Power BI")
    update_system("Microstrategy", "MicroStrategy")
    update_system("postgres", "PostgreSQL")
  end

  def down do
    update_system("unknown", nil)
  end

  defp update_system(nil, to) do
    from(ds in "data_structures", where: is_nil(ds.system), update: [set: [system: ^to]])
    |> Repo.update_all([])
  end

  defp update_system(from, to) do
    from(ds in "data_structures", where: ds.system == ^from, update: [set: [system: ^to]])
    |> Repo.update_all([])
  end
end
