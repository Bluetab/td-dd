defmodule TdDd.Repo.Migrations.RemoveGrantRequestsUpdatedAt do
  use Ecto.Migration

  def change do
    alter table("grant_requests") do
      remove(:updated_at, :utc_datetime_usec)
    end
  end
end
