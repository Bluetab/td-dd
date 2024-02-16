defmodule TdDd.Repo.Migrations.AddTimestampsIndexes do
  use Ecto.Migration

  def change do
    create index("data_structure_versions", [:deleted_at])
    create index("data_structure_versions", [:updated_at])
    create index("data_structures", [:updated_at])
  end
end
