defmodule TdDd.Repo.Migrations.RemoveGrantConstraints do
  use Ecto.Migration

  def up do
    drop constraint("grants", :no_overlap)
    drop constraint("grants", :no_overlap_source_user_name)
  end

  def down do
    create constraint("grants", :no_overlap_source_user_name,
             exclude:
               ~s|gist (data_structure_id WITH =, source_user_name WITH =, daterange(start_date, end_date, '[]') WITH &&)|
           )

    create constraint("grants", :no_overlap,
             exclude:
               ~s|gist (data_structure_id WITH =, user_id WITH =, daterange(start_date, end_date, '[]') WITH &&)|
           )
  end
end
