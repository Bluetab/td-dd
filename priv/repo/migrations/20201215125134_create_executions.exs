defmodule TdDq.Repo.Migrations.CreateExecutions do
  use Ecto.Migration

  def change do
    create table("execution_groups") do
      add(:created_by_id, :integer, null: false)
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create table("executions") do
      add(:group_id, references("execution_groups"), on_delete: :delete_all, null: false)

      add(:implementation_id, references("rule_implementations"),
        on_delete: :delete_all,
        null: false
      )

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create unique_index("executions", [:group_id, :implementation_id])

    alter table("rule_results") do
      add(:execution_id, references("executions"), on_delete: :nilify_all)
    end
  end
end
