defmodule TdDd.Repo.Migrations.CreateFunctions do
  use Ecto.Migration

  def change do
    create table("functions") do
      add :name, :string, null: false
      add :group, :string
      add :scope, :string
      add :args, :map, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end
  end
end
