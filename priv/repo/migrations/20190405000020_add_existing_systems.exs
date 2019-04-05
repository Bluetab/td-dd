defmodule TdDd.Repo.Migrations.AddExistingSystems do
  use Ecto.Migration

  import Ecto.Query
  alias TdDd.Repo
  alias TdDd.DataStructures.System

  @systems %{
    "MicroStrategy" => %{external_id: "mstr", name: "MicroStragegy"},
    "Microstrategy" => %{external_id: "mstr", name: "MicroStragegy"},
    "Azure Blob Storage" => %{external_id: "abs", name: "Azure Blob Storage"},
    "Azure Data Lake Storage" => %{external_id: "adls", name: "Azure Data Lake Storage"},
    "Azure SQL Database" => %{external_id: "azure-sql", name: "Azure SQL Database"},
    "DWH Azure SQL Database" => %{external_id: "azure-sql", name: "Azure SQL Database"},
    "PowerBI" => %{external_id: "pbi", name: "Power BI"},
    "Power BI" => %{external_id: "pbi", name: "Power BI"},
    "postgres" => %{external_id: "postgres", name: "PostgreSQL"},
    "SAP" => %{external_id: "sap", name: "SAP"},
    "SAS" => %{external_id: "sas", name: "SAS"}
  }

  def up do
    distinct_systems =
      fetch_distinct_systems()
      |> format_to_system_definition()

    Repo.insert_all(System, distinct_systems)
  end

  def down do
    Repo.delete_all(System)
  end

  defp fetch_distinct_systems do
    from(d in "data_structures", select: %{name: d.system})
    |> distinct(true)
    |> Repo.all()
  end

  defp format_to_system_definition(systems) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    timestamps = %{inserted_at: now, updated_at: now}

    systems
    |> Enum.map(& &1.name)
    |> Enum.map(&map_system/1)
    |> Enum.uniq()
    |> Enum.map(&Map.merge(&1, timestamps))
  end

  defp map_system(nil), do: map_system("unknown")

  defp map_system(name) do
    case Map.get(@systems, name) do
      nil -> %{external_id: name, name: name}
      sys -> sys
    end
  end
end
