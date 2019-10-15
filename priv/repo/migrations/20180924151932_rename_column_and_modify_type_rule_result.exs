defmodule TdDq.Repo.Migrations.RenameColumnAndModifyTypeRuleResult do
  use Ecto.Migration
  alias Ecto.Adapters.SQL
  alias TdDq.Repo

  @update_implementation_key ~S"""
  UPDATE rule_results
  SET rule_implementation_id = rule_implementations.implementation_key
  FROM rule_implementations
  WHERE rule_results.rule_implementation_id::int = rule_implementations.id
  """

  def change do
    drop(constraint(:rule_results, "rule_results_rule_implementation_id_fkey"))
    alter(table(:rule_results), do: modify(:rule_implementation_id, :string))

    flush()

    SQL.query!(Repo, @update_implementation_key)

    rename(table(:rule_results), :rule_implementation_id, to: :implementation_key)
    create(unique_index(:rule_implementations, [:implementation_key]))
  end
end
