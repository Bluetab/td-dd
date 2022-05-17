defmodule TdDd.Repo.Migrations.AlterGrantsAddSourceUserNameColumn do
  use Ecto.Migration

  def up do
    alter table("grants") do
      modify(:user_id, :bigint, null: true)
      add(:source_user_name, :string)
    end

    drop unique_index("grants", [:data_structure_id, :user_id])

    create(unique_index("grants", [:data_structure_id, :user_id, :source_user_name]))
  end

  def down do
    drop unique_index("grants", [:data_structure_id, :user_id, :source_user_name])

    create(unique_index("grants", [:data_structure_id, :user_id]))

    alter table("grants") do
      modify(:user_id, :bigint, null: false)
      remove(:source_user_name)
    end
  end
end
