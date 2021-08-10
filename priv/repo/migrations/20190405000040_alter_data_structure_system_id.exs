defmodule TdDd.Repo.Migrations.AlterDataStructureSystemId do
  use Ecto.Migration

  def up do
    alter table("data_structures") do
      modify(:system_id, :integer, null: false)
    end
  end

  def down do
    alter table("data_structures") do
      modify(:system_id, :integer, null: true)
    end
  end
end
