defmodule TdDq.Repo.Migrations.AddQualityControlPrinciple do
  use Ecto.Migration

  def change do
    alter table("quality_controls") do
      add(:principle, :map)
    end
  end
end
