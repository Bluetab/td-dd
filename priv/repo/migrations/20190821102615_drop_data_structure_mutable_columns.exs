defmodule TdDd.Repo.Migrations.DropDataStructureMutableColumns do
  use Ecto.Migration

  def up do
    alter table("data_structures") do
      remove(:class)
      remove(:deleted_at)
      remove(:description)
      remove(:group)
      remove(:metadata)
      remove(:name)
      remove(:type)
    end
  end

  def down do
    alter table("data_structures") do
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
