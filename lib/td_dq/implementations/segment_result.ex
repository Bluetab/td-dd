defmodule TdDq.Implementations.SegmentResult do
  @moduledoc """
  Ecto Schema for Data Quality Segment Results.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDq.Rules.RuleResult
  alias TdDq.Results.Helpers

  @scale 2

  schema "segment_results" do
    field(:result, :decimal, precision: 5, scale: @scale)
    field(:records, :integer)
    field(:errors, :integer)
    field(:params, :map, default: %{})
    field(:details, :map, default: %{})

    belongs_to(:rule_result, RuleResult)

    timestamps()
  end

  def changeset(rule_result, %{} = params) do
    changeset(%__MODULE__{}, rule_result, params)
  end

  def changeset(%__MODULE__{} = struct, rule_result, params) do
    struct
    |> cast(params, [
      :result,
      :records,
      :errors,
      :params,
      :details,
    ])
    |> put_assoc(:rule_result, rule_result)
    |> Helpers.maybe_put_result()
    |> update_change(:result, &Decimal.round(&1, @scale, :floor))
    |> validate_required([:rule_result, :result])
    |> validate_number(:records, greater_than_or_equal_to: 0)
    |> validate_number(:errors, greater_than_or_equal_to: 0)
  end



end
