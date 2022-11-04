defmodule TdDd.Repo.Migrations.GrantRequestApprovalRules do
  use Ecto.Migration

  def change do
    create table("approval_rules") do
      add :user_id, :bigint, null: false
      add :domains_ids, {:array, :integer}, default: [], null: false
      add :role, :string, null: false
      add :action, :string, null: false
      add :comment, :string
      add :conditions, {:array, :map}, default: []

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end
  end
end
