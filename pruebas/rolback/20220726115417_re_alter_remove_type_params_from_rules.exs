defmodule TdDd.Repo.Migrations.ReAlterRemoveTypeParamsFromRules do
  use Ecto.Migration

  def change do
    alter table("rules") do
      add(:type_params, :map, null: true)
    end
  end
end
