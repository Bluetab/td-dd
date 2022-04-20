defmodule TdDd.Repo.Migrations.AddSegmentationsToRuleImplementations do
  use Ecto.Migration

  def change do
    alter table("rule_implementations") do
      add(:segmentations, {:array, :map}, default: [])
    end
  end
end
