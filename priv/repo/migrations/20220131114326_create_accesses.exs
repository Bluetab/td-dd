defmodule TdDd.Repo.Migrations.CreateAccesses do
  use Ecto.Migration

  def change do
    create table("accesses") do
      add :user_name, :string
      add :user_external_id, :string
      add :user_id, :bigint
      add :data_structure_external_id, references("data_structures", column: :external_id, type: :text)
      add :source_user_name, :string
      add :details, :map
      add :accessed_at, :utc_datetime, null: true
    end
  end
end
