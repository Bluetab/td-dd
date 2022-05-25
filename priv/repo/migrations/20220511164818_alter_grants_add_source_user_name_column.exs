defmodule TdDd.Repo.Migrations.AlterGrantsAddSourceUserNameColumn do
  use Ecto.Migration

  def up do
    alter table("grants") do
      modify(:user_id, :bigint, null: true)
      add(:source_user_name, :string)
    end

    create constraint("grants", :no_overlap_source_user_name,
             exclude:
               ~s|gist (data_structure_id WITH =, source_user_name WITH =, daterange(start_date, end_date, '[]') WITH &&)|
           )
  end

  def down do
    execute("delete from grants where user_id IS NULL")

    drop constraint("grants", :no_overlap_source_user_name)

    alter table("grants") do
      modify(:user_id, :bigint, null: false)
      remove(:source_user_name)
    end
  end
end
