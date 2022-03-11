defmodule TdDq.Remediations.Remediation do
  @moduledoc """
  Rule execution result remediation plan
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDq.Rules.RuleResult

  schema "remediations" do
    belongs_to(:rule_result, RuleResult)
    field :df_name, :string
    field :df_content, :map
    timestamps()
  end

  def changeset(attrs) do
    changeset(%__MODULE__{}, attrs)
  end

  def changeset(remediation, attrs) do
    remediation
    |> cast(attrs, [:rule_result_id, :df_name, :df_content])
    |> validate_required([:rule_result_id, :df_name, :df_content])
    |> foreign_key_constraint(:rule_result_id)
  end

end
