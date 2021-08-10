defmodule TdDd.Repo.Migrations.AddFieldExternalIdInDataStructures do
  use Ecto.Migration

  def change do
    alter table("data_structures") do
      add :external_id, :string, default: nil, null: true
    end
  end
end
