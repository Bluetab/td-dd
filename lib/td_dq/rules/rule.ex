defmodule TdDq.Rules.Rule do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleType

  @statuses ["defined"]

  schema "rules" do
    field :business_concept_id, :string
    field :description, :string
    field :goal, :integer
    field :minimum, :integer
    field :name, :string
    field :population, :string
    field :priority, :string
    field :weight, :integer
    field :status, :string, default: "defined"
    field :version, :integer, default: 1
    field :updated_by, :integer
    field :principle, :map
    field :type_params, :map
    belongs_to(:rule_type, RuleType)

    timestamps()
  end

  @doc false
  def changeset(%Rule{} = rule, attrs) do
    rule
    |> cast(attrs, [:business_concept_id,
                    :name,
                    :description,
                    :weight,
                    :priority,
                    :population,
                    :goal,
                    :minimum,
                    :status,
                    :version,
                    :updated_by,
                    :principle,
                    :rule_type_id,
                    :type_params])
    |> validate_required([:business_concept_id,
                          :name,
                          :goal,
                          :minimum,
                          :principle,
                          :rule_type_id,
                          :type_params])
    |> validate_number(:goal, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:minimum, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_goal
    |> foreign_key_constraint(:rule_type_id)
  end

  defp validate_goal(changeset) do
    case changeset.valid? do
      true ->
        minimum = get_field(changeset, :minimum)
        goal = get_field(changeset, :goal)
        case minimum <= goal do
          true -> changeset
          false -> add_error(changeset, :goal, "must.be.greater.than.or.equal.to.minimum")
        end
      _ ->
        changeset
    end
end

  def get_statuses do
    @statuses
  end

  def defined_status do
    "defined"
  end
end
