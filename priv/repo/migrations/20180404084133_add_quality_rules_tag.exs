defmodule TdDq.Repo.Migrations.AddQualityRulesTag do
  use Ecto.Migration

  def change do
    alter table("quality_rules") do
      add(:tag, :map, null: true)
    end
  end
end
