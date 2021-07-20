defmodule TdDd.Repo.Migrations.CreateGrants do
  use Ecto.Migration

  def change do
    create table(:grants) do
      add :detail, :map
      add :start_date, :utc_datetime_usec
      add :end_date, :utc_datetime_usec
      add :user_id, :bigint
      add :data_structure_id, references(:data_structures, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:grants, [:data_structure_id, :user_id])
  end
end
