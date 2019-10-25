defmodule TdDq.Rules.RuleImplementation do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation

  schema "rule_implementations" do
    field(:implementation_key, :string)
    field(:system, :string)
    field(:system_params, :map)
    belongs_to(:rule, Rule)

    field(:deleted_at, :utc_datetime)
    timestamps()
  end

  @doc false
  def changeset(%RuleImplementation{} = rule_implementation, attrs) do
    rule_implementation
    |> cast(attrs, [
      :deleted_at,
      :implementation_key,
      :system,
      :system_params,
      :rule_id
    ])
    |> validate_required(required_attrs(rule_implementation))
    |> validate_length(:implementation_key, max: 255)
  end

  defp required_attrs(%RuleImplementation{
         rule: %Rule{
           rule_type: %TdDq.Rules.RuleType{params: %{"system_params" => system_params}}
         }
       }) do
    system_required =
      system_params
      |> Enum.find(fn param -> Map.get(param, "name") == "system_required" end)
      |> case do
        nil -> true
        system_required_props -> Map.get(system_required_props, "value")
      end

    case system_required do
      true ->
        [
          :system,
          :system_params,
          :rule_id
        ]

      false ->
        [
          :system_params,
          :rule_id
        ]
    end
  end

  defp required_attrs(_any) do
    [
      :system,
      :system_params,
      :rule_id
    ]
  end
end
