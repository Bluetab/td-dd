defmodule TdDq.Rules.RuleImplementation do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation
  alias TdDq.Rules.RuleType

  schema "rule_implementations" do
    field(:description, :string, default: nil)
    field(:name, :string)
    field(:type, :string)
    field(:system, :string)
    field(:system_params, :map)
    field(:tag, :map)
    belongs_to(:rule, Rule)
    belongs_to(:rule_type, RuleType)

    timestamps()
  end

  @doc false
  def changeset(%RuleImplementation{} = rule_implementation, attrs) do
    rule_implementation
    |> cast(attrs, [
      :name,
      :description,
      :system,
      :system_params,
      :type,
      :tag,
      :rule_id,
      :rule_type_id
    ])
    |> validate_required([
      :name,
      :type,
      :system,
      :system_params,
      :rule_id,
      :rule_type_id
    ])
    |> validate_length(:name, max: 255)
    |> validate_length(:description, max: 500)
  end
end
