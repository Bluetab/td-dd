defmodule TdDd.Repo.Migrations.DropComments do
  use Ecto.Migration

  def up do
    drop table("comments")
  end

  def down do
    create table("comments") do
      add(:resource_id, :integer)
      add(:resource_type, :string)
      add(:user_id, :integer)
      add(:content, :string)

      timestamps(type: :utc_datetime)
    end
  end
end
