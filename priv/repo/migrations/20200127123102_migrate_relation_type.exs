defmodule TdDd.Repo.Migrations.MigrateRelationType do
  use Ecto.Migration

  import Ecto.Query

  alias TdDd.DataStructures.RelationType
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Repo

  def up do

    default_relation_type = Repo.insert!(%RelationType{name: RelationType.default, description: "Parent/Child"})

    Repo.update_all(
      from(dsr in "data_structure_relations",
        update: [set: [relation_type_id: ^default_relation_type.id]]
      ),
      []
    )

    alter table("data_structure_relations") do
      modify(:relation_type_id, :integer, null: false)
    end

  end

  def down do
    Repo.update_all(
      from(dsr in "data_structure_relations",
        update: [set: [relation_type_id: nil]]
      ),
      []
    )

    default_relation = RelationTypes.get_default_relation_type()
    Repo.delete(default_relation)
  end
end
