defmodule TdDd.Repo.Migrations.AlterDataStructureTagsTimestamps do
  use Ecto.Migration

  def change do
    drop unique_index("data_structures_tags", [:data_structure_id, :data_structure_tag_id])

    rename table("data_structure_tags"), to: table("tags")
    rename table("data_structures_tags"), to: table("structures_tags")

    rename table("structures_tags"), :data_structure_tag_id, to: :tag_id

    alter table("structures_tags") do
      add :inherit, :boolean, default: false, nillable: false
    end

    alter table("tags") do
      modify :inserted_at, :utc_datetime_usec, from: :utc_datetime
      modify :updated_at, :utc_datetime_usec, from: :utc_datetime
    end

    create unique_index("structures_tags", [:data_structure_id, :tag_id])
  end
end
