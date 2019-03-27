defmodule TdDd.Repo.Migrations.AddExistingSystems do
  use Ecto.Migration

  import Ecto.Query
  alias TdDd.Repo
  alias TdDd.DataStructures.System

  @ids_from_systems %{ 
    "MicroStrategy" => "MS01",
    "Microstrategy" => "MS02",
    "Azure Blob Storage" => "ABS01",
    "Azure Data Lake Storage" => "ADLS01",
    "Azure SQL Database" => "ASD01",
    "DWH Azure SQL Database" => "DASD01",
    "PowerBI" => "PBI01",
    "Power BI" => "PBI02",
    "BBDD Oracle" => "OBBDD01",
    "athena-bluetab" => "ATHB01",
    "PhoenixReporting" => "PR01",
    "postgres" => "PG01",
    "SAP" => "SAP01",
    "SAS" => "SAS01",
    "Oracle producción" => "OP01",
    "metadata-oracle" => "MO01"
  }

  def change do 
    distinct_systems = fetch_distinct_systems() 
    |> format_to_system_definition()
    
    Repo.insert_all(System, distinct_systems)
  end

  defp fetch_distinct_systems do
    from(d in "data_structures", select: %{name: d.system})
    |> distinct(true)
    |> Repo.all()
  end

  defp format_to_system_definition(systems) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    systems |> Enum.map(
      &%{
        name: &1.name, 
        external_id: fetch_external_id(&1), 
        inserted_at: now, 
        updated_at: now
      }
    )
  end

  defp fetch_external_id(%{name: name}) do
    Map.get(@ids_from_systems, name, name)
  end
end
