defmodule TdDd.Repo.Migrations.AlterDataStructureClass do
  use Ecto.Migration

  def change do
    alter table(:data_structures) do
      add(:class, :string, null: true)
    end
  end
end
