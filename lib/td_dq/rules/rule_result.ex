defmodule TdDq.Rules.RuleResult do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDq.DateParser
  alias TdDq.Rules.RuleResult

  schema "rule_results" do
    field(:implementation_key, :string)
    field(:date, :utc_datetime)
    field(:result, :integer)
    field(:parent_domains, :string, default: "")
    field(:errors, :integer)
    field(:records, :integer)
    timestamps()
  end

  @doc false
  def changeset(%RuleResult{} = rule_result, attrs) do
    attrs = format_date(attrs)

    rule_result
    |> cast(attrs, [:implementation_key, :date, :parent_domains, :result, :errors, :records])
    |> validate_required([:implementation_key, :date, :result])
  end

  defp format_date(%{"date" => date} = attrs) do
    # Standard datetime formats will be handled by Ecto, we only need to
    # transform non-standard formats (YYYY-MM-DD or YYYY-MM-DD-HH-MM-SS).
    case DateParser.parse(date, [:utc_date, :legacy]) do
      {:ok, datetime, _} -> Map.put(attrs, "date", datetime)
      _ -> attrs
    end
  end

  defp format_date(attrs), do: attrs
end
