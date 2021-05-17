defmodule TdDd.Repo.Migrations.CreateClassifiers do
  use Ecto.Migration

  def change do
    create table("classifiers") do
      add :name, :string, null: false
      add :system_id, references("systems", on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("classifiers", [:system_id, :name])
  end
end
