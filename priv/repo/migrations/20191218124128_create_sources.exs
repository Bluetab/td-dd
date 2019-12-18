defmodule TdCx.Repo.Migrations.CreateSources do
  use Ecto.Migration

  def change do
    create table(:sources) do
      add :type, :string
      add :external_id, :string
      add :secrets, {:array, :map}
      add :config, {:array, :map}

      timestamps(type: :utc_datetime_usec)
    end

  end
end
