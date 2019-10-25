defmodule TdDq.Repo.Migrations.AddQualityControlStatus do
  use Ecto.Migration

  def change do
    alter table("quality_controls") do
      add(:status, :string, default: "defined")
    end
  end
end
