defmodule TdDd.Repo.Migrations.InsertAbsentDataStructureTypes do
  use Ecto.Migration

  def change do
    execute(
      """
      with metadata_types as (
        select distinct type as name from data_structure_versions where deleted_at is null
        except select name from data_structure_types
      )
      insert into data_structure_types(name, inserted_at, updated_at)
      select name, now(), now() from metadata_types
      """,
      ""
    )
  end
end
