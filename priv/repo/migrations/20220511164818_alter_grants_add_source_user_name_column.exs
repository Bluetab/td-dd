defmodule TdDd.Repo.Migrations.AlterGrantsAddSourceUserNameColumn do
  use Ecto.Migration

  def up do
    alter table("grants") do
      modify(:user_id, :bigint, null: true)
      add(:source_user_name, :string)
    end
  end

  def down do
    execute(
      "delete from grants where user_id IS NULL"
    )

    alter table("grants") do
      modify(:user_id, :bigint, null: false)
      remove(:source_user_name)
    end
  end
end
