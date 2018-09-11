defmodule TdDq.Rules.RuleResult do
  @moduledoc false
  use Ecto.Schema
  alias TdDq.Rules.RuleImplementation

  schema "rule_results" do
    belongs_to(:rule_implementation, RuleImplementation)
    field :date, :utc_datetime
    field :result, :integer

    timestamps()
  end
end
