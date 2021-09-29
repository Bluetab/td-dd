defmodule TdDd.Repo.Migrations.AddDomainIdToGrantRequests do
  use Ecto.Migration

  def change do
    alter table("grant_requests") do
      add(:domain_id, :integer)
    end
  end
end
