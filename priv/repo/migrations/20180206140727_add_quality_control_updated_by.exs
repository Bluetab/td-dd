defmodule TdDq.Repo.Migrations.AddQualityControlUpdatedBy do
  use Ecto.Migration

  def change do
    alter table("quality_controls") do
      add(:updated_by, :integer)
    end
  end
end
