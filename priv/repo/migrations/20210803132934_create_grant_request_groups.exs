defmodule TdDd.Repo.Migrations.CreateGrantRequestGroups do
  use Ecto.Migration

  def change do
    create table(:grant_request_groups) do
      add :request_date, :utc_datetime_usec, null: false
      add :user_id, :integer, null: false
      add :type, :string

      timestamps()
    end
  end
end
