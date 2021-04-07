defmodule TdCx.Repo.Migrations.AddSourceDeletedAt do
  use Ecto.Migration

  def up do
    alter table(:sources) do
      add :deleted_at, :utc_datetime, null: true
    end
    drop(unique_index(:sources, [:external_id]))
    create(
      unique_index(:sources, [:external_id], where: "deleted_at IS NULL")
    )
  end

  def down do
    alter(table(:sources), do: remove(:deleted_at))
    create(unique_index(:sources, [:external_id]))
  end
end
