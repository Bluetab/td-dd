defmodule TdDd.Repo.Migrations.AddDataStructuresTags do
  use Ecto.Migration

  def change do
    create table("data_structures_tags") do
      add(:data_structure_id, references("data_structures", on_delete: :delete_all))
      add(:data_structure_tag_id, references("data_structure_tags", on_delete: :delete_all))
      add(:description, :string, size: 1_000, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("data_structures_tags", [:data_structure_id, :data_structure_tag_id])
  end
end
