defmodule TdDd.Repo.Migrations.CreateRelationTypes do
  use Ecto.Migration

  def up do
    create table("relation_types") do
      add :name, :string, null: false
      add :description, :string, null: true

      timestamps()
    end

    create unique_index("relation_types", [:name], name: :index_relation_types_name)

    alter table("data_structure_relations") do
      add(:relation_type_id, references("relation_types"), null: true)
    end
  end

  def down do
    alter table("data_structure_relations") do
      remove :relation_type_id
    end

    drop table("relation_types")
  end
end
