defmodule TdDq.Repo.Migrations.AddSystemRequiredToRule do
  use Ecto.Migration

  def up do
    alter(table(:rules), do: add(:system_required, :boolean, default: true))
  end

  def down do
    alter(table(:rules), do: remove(:system_required))
  end
end
