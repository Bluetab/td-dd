defmodule TdDd.Repo.Migrations.AddReasonToGrantRequestStatus do
  use Ecto.Migration

  def change do
    alter table("grant_request_status") do
      add :reason, :string
    end
  end
end
