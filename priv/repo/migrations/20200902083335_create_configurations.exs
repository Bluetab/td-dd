defmodule TdCx.Repo.Migrations.CreateConfigurations do
  use Ecto.Migration

  def up do
    create table(:configurations) do
      add :content, :map
      add :external_id, :string, null: false
      add :secrets_key, :string
      add :type, :string, null: false
      add :deleted_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:configurations, [:external_id])
  end

  def down do
    drop unique_index(:configurations, [:external_id])
    drop table(:configurations)
  end
end
