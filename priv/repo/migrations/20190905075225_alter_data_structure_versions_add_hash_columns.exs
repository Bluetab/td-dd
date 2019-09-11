defmodule TdDd.Repo.Migrations.AlterDataStructureVersionsAddHashColumns do
  use Ecto.Migration

  def change do
    alter table(:data_structure_versions) do
      add(:hash, :bytea, default: nil, null: true)
      add(:lhash, :bytea, default: nil, null: true)
      add(:ghash, :bytea, default: nil, null: true)
    end

    create(index("data_structure_versions", [:hash]))
  end
end
