defmodule TdDq.Rules.RuleResult do
  @moduledoc false
  use Ecto.Schema

  schema "rule_results" do
    field(:implementation_key, :string)
    field :date, :utc_datetime
    field :result, :integer
    field :parent_domains, :string

    timestamps()
  end
end
