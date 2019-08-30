defmodule TdDq.Rules.RuleResult do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.Rules.RuleResult

  schema "rule_results" do
    field :implementation_key, :string
    field :date, :utc_datetime
    field :result, :integer
    field :parent_domains, :string, default: ""
    field :errors, :integer
    field :records, :integer
    timestamps()
  end

  @doc false
  def changeset(%RuleResult{} = rule_result, attrs) do
    rule_result
    |> cast(attrs, [:implementation_key, :date, :parent_domains, :result, :errors, :records])
    |> validate_required([:implementation_key, :date, :result])
  end
end
