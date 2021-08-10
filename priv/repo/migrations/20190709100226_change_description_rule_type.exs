defmodule TdDq.Repo.Migrations.ChangeDescriptionRuleType do
  use Ecto.Migration

  def change do
    alter table("rules") do
      modify(:description, :text)
    end
  end
end
