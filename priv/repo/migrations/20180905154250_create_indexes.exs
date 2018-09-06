defmodule TdDq.Repo.Migrations.CreateIndexes do
  use Ecto.Migration

  def up do
    create unique_index(:rule_types, [:name])
  end

  def down do
    drop unique_index(:rule_types, [:name])    
  end

end
