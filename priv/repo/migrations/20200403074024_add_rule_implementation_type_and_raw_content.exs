defmodule TdDq.Repo.Migrations.AddRuleImplementationTypeAndRawContent do
  use Ecto.Migration

  def change do
    alter table(:rule_implementations) do
      add(:raw_content, :map, default: %{})
      add(:implementation_type, :string, default: "default")
    end
  end
end
