defmodule TdDd.Repo.Migrations.GrantRequestApprovalRules do
  use Ecto.Migration

  def change do
    create table("approval_rules") do
      add :name, :string
      add :user_id, :bigint, null: false
      add :domain_ids, {:array, :integer}, default: [], null: false
      add :role, :string, null: false
      add :action, :string, null: false
      add :comment, :string
      add :conditions, {:array, :map}, default: []

      timestamps(type: :utc_datetime_usec)
    end

    alter table("grant_request_approvals") do
      add :approval_rule_id, references("approval_rules", on_delete: :nilify_all), null: true
    end
  end
end
