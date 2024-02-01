defmodule TdDd.Repo.Migrations.CreateRemediation do
  use Ecto.Migration
  alias TdDq.Rules.RuleResult
  def change do
    create table("remediations") do
      add(:rule_result_id, references("rule_results", on_delete: :delete_all))
      add(:df_name, :string)
      add(:df_content, :map)

      timestamps(type: :utc_datetime_usec)
    end
  end
end
