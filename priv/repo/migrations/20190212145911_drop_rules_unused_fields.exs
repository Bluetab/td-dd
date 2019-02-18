defmodule TdDq.Repo.Migrations.DropRulesUnusedFields do
  use Ecto.Migration

  def change do
    alter table(:rules) do
      remove :type_backup
      remove :status_backup
    end
  end
end
