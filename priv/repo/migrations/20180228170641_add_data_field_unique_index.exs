defmodule TdDd.Repo.Migrations.AddDataFieldUniqueIndex do
  use Ecto.Migration

  def change do
    create unique_index("data_fields", [:data_structure_id, :name])
  end
end
