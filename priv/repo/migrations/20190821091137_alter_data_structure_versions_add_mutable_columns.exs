defmodule TdDd.Repo.Migrations.AlterDataStructureVersionsAddMutableColumns do
  use Ecto.Migration

  def change do
    alter table("data_structure_versions") do
      add(:class, :string)
      add(:deleted_at, :utc_datetime)
      add(:description, :text)
      add(:group, :string)
      add(:metadata, :map)
      add(:name, :string)
      add(:type, :string)
    end
  end
end
