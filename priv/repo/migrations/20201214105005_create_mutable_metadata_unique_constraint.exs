defmodule TdDd.Repo.Migrations.CreateMutableMetadataUniqueConstraint do
  use Ecto.Migration

  def change do
    create unique_index("structure_metadata", [:data_structure_id, :version])
  end
end
