defmodule TdDd.Repo.Migrations.AddExistingSystems do
  use Ecto.Migration

  import Ecto.Query
  alias TdDd.Repo
  alias TdDd.DataStructures.System

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
        external_ref: &1.name, 
        inserted_at: now, 
        updated_at: now
      }
    )
  end
end
