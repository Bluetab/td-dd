defmodule TdDq.Repo.Migrations.AddTagsFieldToRule do
  use Ecto.Migration

  def up do
    alter(table(:rules), do: add(:tag, :map, null: true))
  end

  def down do
    alter(table(:rules), do: remove(:tag))
  end
end
