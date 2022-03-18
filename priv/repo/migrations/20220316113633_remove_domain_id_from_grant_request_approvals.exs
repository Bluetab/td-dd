defmodule TdDd.Repo.Migrations.RemoveDomainIdFromGrantRequestApprovals do
  use Ecto.Migration

  def change do
    alter table("grant_request_approvals") do
      remove :domain_id, :integer
    end
  end
end
