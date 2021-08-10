defmodule TdDd.Repo.Migrations.CreateGrantRequestGroups do
  use Ecto.Migration

  def change do
    create table("grant_request_groups") do
      add :user_id, :integer, null: false
      add :type, :string

      timestamps(type: :utc_datetime_usec)
    end
  end
end
