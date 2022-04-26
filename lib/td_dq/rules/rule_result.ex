defmodule TdDq.Rules.RuleResult do
  @moduledoc """
  Ecto Schema module for Data Quality Rule Results.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Decimal
  alias TdDq.Executions.Execution
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.SegmentResult
  alias TdDq.Remediations.Remediation
  alias TdDq.Results.Helpers
  alias TdDq.Rules.Rule

  @scale 2
  @valid_result_types Implementation.valid_result_types()

  @typedoc "The result of a quality rule execution"
  @type t :: %__MODULE__{}

  schema "rule_results" do
    field(:date, :utc_datetime)
    field(:result, :decimal, precision: 5, scale: @scale)
    field(:errors, :integer)
    field(:records, :integer)
    field(:params, :map, default: %{})
    field(:row_number, :integer, virtual: true)
    field(:result_type, :string)
    field(:details, :map, default: %{})

    belongs_to(:implementation, Implementation)
    belongs_to(:rule, Rule)

    has_many(:execution, Execution, foreign_key: :result_id)
    has_many(:segment_result, SegmentResult, foreign_key: :rule_result_id)
    has_one(:remediation, Remediation)

    timestamps()
  end

  def changeset(implementation, %{} = params) do
    changeset(%__MODULE__{}, implementation, params)
  end

  def changeset(%__MODULE__{} = struct, implementation, params) do
    struct
    |> cast(params, [
      :result,
      :errors,
      :records,
      :params,
      :row_number,
      :result_type,
      :details
    ])
    |> put_assoc(:implementation, implementation)
    |> Helpers.put_date()
    |> Helpers.maybe_put_result()
    |> validate_inclusion(:result_type, @valid_result_types)
    |> update_change(:result, &Decimal.round(&1, @scale, :floor))
    |> validate_required([:implementation, :date, :result, :result_type, :rule_id])
    |> validate_number(:records, greater_than_or_equal_to: 0)
    |> validate_number(:errors, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:rule_id)
  end
end
