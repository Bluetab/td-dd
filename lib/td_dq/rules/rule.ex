defmodule TdDq.Rules.Rule do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation
  alias TdDq.Rules.RuleType

  schema "rules" do
    field(:business_concept_id, :string)
    field(:active, :boolean, default: false)
    field(:deleted_at, :utc_datetime)
    field(:description, :string)
    field(:goal, :integer)
    field(:minimum, :integer)
    field(:name, :string)
    field(:population, :string)
    field(:priority, :string)
    field(:weight, :integer)
    field(:version, :integer, default: 1)
    field(:updated_by, :integer)
    field(:type_params, :map)
    belongs_to(:rule_type, RuleType)

    has_many(:rule_implementations, RuleImplementation)

    field(:df_name, :string)
    field(:df_content, :map)

    timestamps()
  end

  @doc false
  def changeset(%Rule{} = rule, attrs) do
    rule
    |> cast(attrs, [
      :business_concept_id,
      :active,
      :name,
      :deleted_at,
      :description,
      :weight,
      :priority,
      :population,
      :goal,
      :minimum,
      :version,
      :updated_by,
      :rule_type_id,
      :type_params,
      :df_name,
      :df_content
    ])
    |> validate_required([
      :name,
      :goal,
      :minimum,
      :rule_type_id,
      :type_params
    ])
    |> unique_constraint(
      :rule_name_bc_id,
      name: :rules_business_concept_id_name_index,
      message: "unique_constraint"
    )
    |> unique_constraint(
      :rule_name_bc_id,
      name: :rules_name_index,
      message: "unique_constraint"
    )
    |> validate_number(:goal, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:minimum, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_goal
    |> foreign_key_constraint(:rule_type_id)
  end

  def delete_changeset(%Rule{} = rule) do
    rule
    |> change()
    |> no_assoc_constraint(:rule_implementations, message: "rule.delete.existing.implementations")
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
end
