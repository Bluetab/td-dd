defmodule TdDq.Rules.Implementations.Implementation do
  @moduledoc """
  Ecto Schema module for Quality Rule Implementations
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias TdDq.Rules.Implementations
  alias TdDq.Rules.Implementations.ConditionRow
  alias TdDq.Rules.Implementations.DatasetRow
  alias TdDq.Rules.Implementations.RawContent
  alias TdDq.Rules.Rule

  schema "rule_implementations" do
    field(:implementation_key, :string)
    field(:implementation_type, :string, default: "default")

    embeds_many(:dataset, DatasetRow, on_replace: :delete)
    embeds_many(:population, ConditionRow, on_replace: :delete)
    embeds_many(:validations, ConditionRow, on_replace: :delete)

    embeds_one(:raw_content, RawContent, on_replace: :delete)

    belongs_to(:rule, Rule)

    field(:deleted_at, :utc_datetime)
    timestamps()
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = implementation, params) do
    implementation
    |> cast(params, [
      :deleted_at,
      :rule_id,
      :implementation_key,
      :implementation_type
    ])
    |> validate_required([:implementation_type, :rule_id])
    |> validate_inclusion(:implementation_type, ["default", "raw"])
    |> validate_or_put_implementation_key()
    |> foreign_key_constraint(:rule_id)
    |> custom_changeset(implementation)
  end

  defp validate_or_put_implementation_key(%Changeset{valid?: true} = changeset) do
    case get_field(changeset, :implementation_key) do
      nil ->
        put_change(changeset, :implementation_key, Implementations.next_key())

      _ ->
        changeset
        |> validate_required([:implementation_key])
        |> validate_length(:implementation_key, max: 255)
        |> validate_format(:implementation_key, ~r/^[A-z0-9]*$/)
    end
  end

  defp validate_or_put_implementation_key(%Changeset{} = changeset), do: changeset

  defp custom_changeset(
         %Changeset{changes: %{implementation_type: "raw"}} = changeset,
         _implementation
       ) do
    raw_changeset(changeset)
  end

  defp custom_changeset(%Changeset{} = changeset, %__MODULE__{implementation_type: "raw"}) do
    raw_changeset(changeset)
  end

  defp custom_changeset(
         %Changeset{changes: %{implementation_type: _type}} = changeset,
         _implementation
       ) do
    default_changeset(changeset)
  end

  defp custom_changeset(%Changeset{} = changeset, %__MODULE__{implementation_type: _type}) do
    default_changeset(changeset)
  end

  defp raw_changeset(changeset) do
    changeset
    |> cast_embed(:raw_content, with: &RawContent.changeset/2, required: true)
    |> validate_required([:raw_content])
  end

  def default_changeset(changeset) do
    changeset
    |> cast_embed(:dataset, with: &DatasetRow.changeset/2, required: true)
    |> cast_embed(:population, with: &ConditionRow.changeset/2, required: false)
    |> cast_embed(:validations, with: &ConditionRow.changeset/2, required: true)
    |> validate_required([:dataset, :validations])
  end
end
