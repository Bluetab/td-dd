defmodule TdCx.Repo.Migrations.CreateSources do
  use Ecto.Migration

  def change do
    create table(:sources) do
      add :external_id, :string
      add :config, :map
      add :secrets_key, :string
      add :type, :string

      timestamps(type: :utc_datetime_usec)
    end
    create unique_index(:sources, [:external_id])
  end
end
