defmodule TdDd.Repo.Migrations.AddExternalRefToGrant do
  use Ecto.Migration

  def up do
    alter table("grants") do
      add(:external_ref, :string, null: true)
    end

    create constraint("grants", :no_overlap_source_user_name,
             exclude:
               ~s|gist (data_structure_id WITH =, source_user_name WITH =, external_ref WITH =, daterange(start_date, end_date, '[]') WITH &&)|
           )
  end

  def down do
    drop constraint("grants", :no_overlap_source_user_name)

    alter table("grants") do
      remove(:external_ref)
    end
  end
end
