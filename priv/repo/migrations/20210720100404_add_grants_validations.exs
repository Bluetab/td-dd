defmodule TdDd.Repo.Migrations.AddGrantsValidations do
  use Ecto.Migration

  def up do
    drop(unique_index(:grants, [:data_structure_id, :user_id]))

    alter table(:grants) do
      modify(:user_id, :bigint, null: false)
      modify(:start_date, :utc_datetime_usec, null: false)
    end

    create(index(:grants, [:data_structure_id, :user_id]))
  end

  def down do
    drop(index(:grants, [:data_structure_id, :user_id]))

    alter table(:grants) do
      modify(:user_id, :bigint, null: true)
      modify(:start_date, :utc_datetime_usec, null: true)
    end

    create(unique_index(:grants, [:data_structure_id, :user_id]))
  end
end
