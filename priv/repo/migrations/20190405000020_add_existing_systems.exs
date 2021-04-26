defmodule TdDd.Repo.Migrations.AddExistingSystems do
  use Ecto.Migration

  import Ecto.Query
  alias TdDd.Repo
  alias TdDd.Systems.System

  @systems %{
    "MicroStrategy" => %{external_id: "mstr", name: "MicroStrategy"},
    "Azure Blob Storage" => %{external_id: "abs", name: "Azure Blob Storage"},
    "Azure Data Lake Storage" => %{external_id: "adls", name: "Azure Data Lake Storage"},
    "Azure SQL Database" => %{external_id: "azsql", name: "Azure SQL Database"},
    "DWH Azure SQL Database" => %{external_id: "azsql", name: "Azure SQL Database"},
    "Power BI" => %{external_id: "powerbi", name: "Power BI"},
    "PostgreSQL" => %{external_id: "postgres", name: "PostgreSQL"},
    "SAP" => %{external_id: "sap", name: "SAP"},
    "SAS" => %{external_id: "sas", name: "SAS"}
  }

  defp system_from_name(name), do: Map.get(@systems, name, %{external_id: name, name: name})

  def up do
    timestamps = get_timestamps(NaiveDateTime.utc_now())

    systems =
      from(ds in "data_structures", distinct: true, select: ds.system)
      |> Repo.all()
      |> Enum.map(&system_from_name/1)
      |> Enum.map(&Map.merge(&1, timestamps))

    Repo.insert_all(System, systems)
  end

  defp get_timestamps(ts) do
    ts = ts |> NaiveDateTime.truncate(:second)
    %{inserted_at: ts, updated_at: ts}
  end

  def down do
    Repo.delete_all(System)
    execute("update data_structures set system=null where system = 'unknown';")
  end
end
