defmodule TdDd.Repo.Migrations.CreateStructureClassifications do
  use Ecto.Migration

  def change do
    create table("structure_classifications") do
      add :classifier_id, references("classifiers", on_delete: :delete_all), null: false
      add :data_structure_version_id, references("data_structure_versions", on_delete: :delete_all), null: false
      add :rule_id, references("classifier_rules", on_delete: :delete_all)
      add :class, :string, null: false
      add :name, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("structure_classifications", [:data_structure_version_id, :classifier_id])
  end
end
