defmodule TdDq.Repo.Migrations.AddResultTypeToRule do
  use Ecto.Migration

  def up do
    alter(table(:rules), do: add(:result_type, :string, default: "percentage"))
  end

  def down do
    alter(table(:rules), do: remove(:result_type))
  end
end
