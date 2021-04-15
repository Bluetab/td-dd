defmodule TdDq.Repo.Migrations.FixReferencesOnExecutions do
  use Ecto.Migration

  def change do
    drop(constraint("executions", :executions_implementation_id_fkey))
    drop(constraint("executions", :executions_group_id_fkey))

    alter table("executions") do
      modify(:group_id, references("execution_groups", on_delete: :delete_all), null: false)
      modify(:implementation_id, references("rule_implementations", on_delete: :delete_all), null: false)
    end
  end
end
