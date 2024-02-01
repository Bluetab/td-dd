defmodule TdDd.Repo.Migrations.AlterRemoveTypeParamsFromRules do
  use Ecto.Migration

  def change do
    alter table("rules") do
      remove(:type_params, :map, null: true)
    end
  end
end
