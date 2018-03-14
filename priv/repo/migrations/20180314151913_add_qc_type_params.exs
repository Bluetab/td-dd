defmodule TdDq.Repo.Migrations.AddQcTypeParams do
  use Ecto.Migration

  def change do
    alter table(:quality_controls) do
      add :type_params, :map, null: true
    end
  end
end
