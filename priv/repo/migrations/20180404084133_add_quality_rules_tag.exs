defmodule TdDq.Repo.Migrations.AddQualityRulesTag do
  use Ecto.Migration

  def change do
    alter table(:quality_rules) do
      add :tag, :string
    end
  end
end
