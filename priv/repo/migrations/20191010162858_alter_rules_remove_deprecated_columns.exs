defmodule TdDq.Repo.Migrations.AlterRulesRemoveDeprecatedColumns do
  use Ecto.Migration

  def change do
    alter table("rules") do
      remove(:population)
      remove(:priority)
      remove(:weight)
    end
  end
end
