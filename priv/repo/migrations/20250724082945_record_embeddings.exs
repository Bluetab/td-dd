defmodule TdDd.Repo.Migrations.RecordEmbeddings do
  use Ecto.Migration

  def change do
    create table(:record_embeddings) do
      add :collection, :string, null: false
      add :dims, :integer, null: false
      add :embedding, {:array, :float}, null: false

      add :data_structure_version_id,
          references(:data_structure_versions, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:record_embeddings, [:updated_at])
    create index(:record_embeddings, [:data_structure_version_id])
    create index(:record_embeddings, [:data_structure_version_id, :collection], unique: true)
  end
end
