defmodule TdDq.QualityRules.QualityRule do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.QualityControls.QualityControl
  alias TdDq.QualityRules.QualityRule
  alias TdDq.QualityRules.QualityRuleType

  schema "quality_rules" do
    field :description, :string, default: nil
    field :name, :string
    field :type_params, :map
    field :system, :string
    field :type, :string
    field :tag, :map
    belongs_to :quality_control, QualityControl
    belongs_to :quality_rule_type, QualityRuleType

    timestamps()
  end

  @doc false
  def changeset(%QualityRule{} = quality_rule, attrs) do
    quality_rule
    |> cast(attrs, [:name, :description, :system, :type_params, :type, :tag, :quality_control_id, :quality_rule_type_id])
    |> validate_required([:name, :description, :system, :type_params, :type, :tag, :quality_control_id, :quality_rule_type_id])
    |> validate_length(:name, max: 255)
    |> validate_length(:description, max: 500)
  end
end
