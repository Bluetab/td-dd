defmodule TdDd.Repo.Migrations.CreateDataStructuresLinks do
  use Ecto.Migration

  def change do
    create table("data_structures_links") do
      add(:source_id, references("data_structures"))
      add(:target_id, references("data_structures"))
      add(:source_external_id, :string)
      add(:target_external_id, :string)
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("data_structures_links", [:source_id, :target_id])
  end
end
