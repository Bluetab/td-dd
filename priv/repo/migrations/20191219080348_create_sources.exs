defmodule TdCx.Repo.Migrations.CreateSources do
  use Ecto.Migration

  def change do
    create table(:sources) do
      add :external_id, :string
      add :config, {:array, :map}
      add :secrets_key, :string
      add :type, :string

      timestamps(type: :utc_datetime_usec)
    end

  end
end
