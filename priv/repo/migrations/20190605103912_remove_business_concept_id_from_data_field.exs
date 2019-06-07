defmodule TdDd.Repo.Migrations.RemoveBusinessConceptIdFromDataField do
  use Ecto.Migration

  def up do
    alter table(:data_fields) do
      remove(:business_concept_id)
    end
  end

  def down do
    alter table(:data_fields) do
      add :business_concept_id, :string, default: nil, null: true
    end
  end
end
