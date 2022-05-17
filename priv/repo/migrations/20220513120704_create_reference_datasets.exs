defmodule TdDd.Repo.Migrations.CreateReferenceDatasets do
  use Ecto.Migration

  def change do
    create table("reference_datasets") do
      add :name, :string, null: false
      add :headers, {:array, :string}, null: false
      add :rows, {:array, {:array, :string}}, null: false
      timestamps(type: :utc_datetime_usec)
    end
  end
end
