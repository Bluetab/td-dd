defmodule TdDq.Repo.Migrations.CreateQualityControlsResults do
  use Ecto.Migration

  def change do
    create table(:quality_controls_results) do
      add(:business_concept_id, :string)
      add(:quality_control_name, :string)
      add(:system, :string)
      add(:group, :string)
      add(:structure_name, :string)
      add(:field_name, :string)
      add(:date, :utc_datetime)
      add(:result, :integer)

      timestamps()
    end
  end
end
