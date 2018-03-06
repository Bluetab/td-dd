defmodule TdDQ.Repo.Migrations.AddQualityControlVersion do
  use Ecto.Migration

  def change do
    alter table("quality_controls") do
      add :version, :integer, default: 1
    end
  end
end
