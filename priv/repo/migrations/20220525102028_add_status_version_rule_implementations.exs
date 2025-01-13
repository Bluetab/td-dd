defmodule TdDd.Repo.Migrations.AddStatusVersionRuleImplementations do
  use Ecto.Migration

  @valid_statuses "'draft', 'pending_approval', 'rejected', 'published', 'versioned', 'deprecated'"

  def up do
    create_query = "CREATE TYPE rule_implementations_status AS ENUM (#{@valid_statuses})"
    execute(create_query)

    alter table("rule_implementations") do
      add(:status, :rule_implementations_status)
      add(:version, :integer)
    end

    execute(
      "UPDATE rule_implementations SET status = 'published', version = 1 WHERE deleted_at IS NULL"
    )

    execute(
      "UPDATE rule_implementations SET status = 'deprecated', version = 1 WHERE deleted_at IS NOT NULL"
    )

    alter table("rule_implementations") do
      modify(:status, :rule_implementations_status, null: false)
      modify(:version, :integer, null: false)
    end

    drop unique_index("rule_implementations", [:implementation_key], where: "deleted_at IS NULL")

    create unique_index("rule_implementations", [:implementation_key],
             where: "deleted_at IS NULL AND status = 'published'",
             name: :published_implementation_key_index
           )

    create unique_index("rule_implementations", [:implementation_key],
             where: "deleted_at IS NULL AND status in ('draft', 'pending_approval', 'rejected')",
             name: :draft_implementation_key_index
           )
  end

  def down do
    drop unique_index("rule_implementations", [:implementation_key],
           where: "deleted_at IS NULL AND status = 'published'",
           name: :published_implementation_key_index
         )

    drop unique_index("rule_implementations", [:implementation_key],
           where: "deleted_at IS NULL AND status in ('draft', 'pending_approval', 'rejected')",
           name: :draft_implementation_key_index
         )

    create unique_index("rule_implementations", [:implementation_key],
             where: "deleted_at IS NULL"
           )

    alter table("rule_implementations") do
      remove(:version)
      remove(:status)
    end

    drop_query = "DROP TYPE rule_implementations_status"
    execute(drop_query)
  end
end
