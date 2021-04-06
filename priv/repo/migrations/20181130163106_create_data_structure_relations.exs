defmodule TdDd.Repo.Migrations.CreateDataStructureRelations do
  use Ecto.Migration

  def up do
    create table(:data_structure_relations) do
      add(:parent_id, references(:data_structure_versions))
      add(:child_id, references(:data_structure_versions))
      timestamps(type: :utc_datetime)
    end

    create(index(:data_structure_relations, [:parent_id]))
    create(index(:data_structure_relations, [:child_id]))
  end

  def down do
    drop table(:data_structure_relations)
  end
end
