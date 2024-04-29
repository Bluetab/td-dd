defmodule TdDq.Remediations.Remediation do
  @moduledoc """
  Rule execution result remediation plan
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDfLib.Validation
  alias TdDq.Rules.RuleResult

  schema "remediations" do
    belongs_to(:rule_result, RuleResult)
    field(:df_name, :string)
    field(:df_content, :map)
    field(:user_id, :integer)
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(attrs) do
    changeset(%__MODULE__{}, attrs)
  end

  def changeset(remediation, attrs) do
    remediation
    |> cast(attrs, [:rule_result_id, :df_name, :df_content, :user_id])
    |> validate_required([:rule_result_id, :df_name, :df_content, :user_id])
    |> validate_content(remediation)
    |> foreign_key_constraint(:rule_result_id)
  end

  defp validate_content(
         %Ecto.Changeset{valid?: true, changes: %{df_name: df_name, df_content: df_content}} =
           changeset,
         _remediation
       )
       when map_size(df_content) !== 0 do
    validate_change(changeset, :df_content, Validation.validator(df_name))
  end

  defp validate_content(
         %Ecto.Changeset{valid?: true, changes: %{df_content: df_content}} = changeset,
         %__MODULE__{df_name: df_name}
       )
       when map_size(df_content) !== 0 do
    validate_change(changeset, :df_content, Validation.validator(df_name))
  end

  defp validate_content(changeset, _), do: changeset
end
