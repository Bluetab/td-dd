defmodule TdDq.Rules.RuleImplementation do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation

  schema "rule_implementations" do
    field(:description, :string, default: nil)
    field(:implementation_key, :string)
    field(:system, :string)
    field(:system_params, :map)
    field(:tag, :map)
    belongs_to(:rule, Rule)

    timestamps()
  end

  @doc false
  def changeset(%RuleImplementation{} = rule_implementation, attrs) do
    rule_implementation
    |> cast(attrs, [
      :implementation_key,
      :description,
      :system,
      :system_params,
      :tag,
      :rule_id
    ])
    |> validate_required([
      :implementation_key,
      :system,
      :system_params,
      :rule_id
    ])
    |> validate_length(:implementation_key, max: 255)
    |> validate_length(:description, max: 500)
  end
end
