defmodule TdDq.Rules.RuleResult do
  @moduledoc false
  use Ecto.Schema

  schema "rule_results" do
    field :business_concept_id, :string
    field :rule, :string
    field :system, :string
    field :group, :string
    field :structure_name, :string
    field :field_name, :string
    field :date, :utc_datetime
    field :result, :integer

    timestamps()
  end
end
