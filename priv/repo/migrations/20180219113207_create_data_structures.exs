defmodule TdDd.Repo.Migrations.CreateDataStructures do
  use Ecto.Migration

  def change do
    create table("data_structures") do
      add :system, :string
      add :group, :string
      add :name, :string
      add :description, :text, null: true
      add :last_change_at, :utc_datetime
      add :last_change_by, :bigint

      timestamps(type: :utc_datetime)
    end
  end
end
