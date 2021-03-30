defmodule TdDd.Repo.Migrations.CreateExecutions do
  use Ecto.Migration

  def change do
    create table("execution_groups") do
      add(:created_by_id, :integer, null: false)
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create table("executions") do
      add(:group_id, references("execution_groups"), on_delete: :delete_all, null: false)
      add(:data_structure_id, references("data_structures"), on_delete: :delete_all, null: false)
      add(:profile_id, references(:profiles, on_delete: :nilify_all))
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("executions", [:group_id, :data_structure_id])
  end
end
