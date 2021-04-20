defmodule TdDq.Repo.Migrations.AddExecutionsResultId do
  use Ecto.Migration

  def change do
    alter table("executions") do
      add(:result_id, references(:rule_results, on_delete: :nilify_all))
      add(:updated_at, :utc_datetime_usec)
    end

    execute(
      "UPDATE executions SET result_id = rr.id FROM rule_results AS rr WHERE rr.execution_id = executions.id",
      ""
    )

    execute("UPDATE executions SET updated_at = inserted_at", "")
  end
end
