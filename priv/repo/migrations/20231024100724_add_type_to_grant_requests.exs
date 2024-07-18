defmodule TdDd.Repo.Migrations.AddTypeToGrantRequests do
  use Ecto.Migration

  @delete_data true

  def change do
    alter table("grant_requests") do
      add :request_type, :string
      add :grant_id, references("grants")
    end

    create constraint("grant_requests", :only_one_resource,
             check: "num_nonnulls(data_structure_id, grant_id) = 1"
           )

    execute(&execute_up/0, &execute_down/0)
  end

  # https://hexdocs.pm/ecto_sql/Ecto.Migration.html#modify/3
  # If you want to modify a column without changing its type, such as adding or
  # dropping a null constraints, consider using the execute/2 command with the
  # relevant SQL command instead of modify/3, if supported by your database.
  # This may avoid redundant type updates and be more efficient, as an
  # unnecessary type update can lock the table, even if the type actually doesn't
  # change.

  defp execute_up do
    repo().transaction(fn migrator_repo ->
      migrator_repo.query!(
        "ALTER TABLE grant_requests ALTER COLUMN data_structure_id DROP NOT NULL",
        [],
        log: :info
      )
    end)
  end

  defp execute_down do
    repo().transaction(fn migrator_repo ->
      if @delete_data do
        migrator_repo.query!("DELETE FROM grant_requests WHERE data_structure_id IS NULL", [],
          log: :info
        )
      end

      migrator_repo.query!(
        "ALTER TABLE grant_requests ALTER COLUMN data_structure_id SET NOT NULL;",
        [],
        log: :info
      )
    end)
  end
end
