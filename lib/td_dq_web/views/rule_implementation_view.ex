defmodule TdDqWeb.RuleImplementationView do
  use TdDqWeb, :view
  alias TdDqWeb.RuleImplementationView

  def render("index.json", %{rule_implementations: rule_implementations}) do
    %{data: render_many(rule_implementations, RuleImplementationView, "rule_implementation.json")}
  end

  def render("show.json", %{rule_implementation: rule_implementation}) do
    %{data: render_one(rule_implementation, RuleImplementationView, "rule_implementation.json")}
  end

  def render("rule_implementation.json", %{rule_implementation: rule_implementation}) do
    %{
      id: rule_implementation.id,
      rule_id: rule_implementation.rule_id,
      implementation_key: rule_implementation.implementation_key,
      system: rule_implementation.system,
      system_params: rule_implementation.system_params,
      deleted_at: rule_implementation.deleted_at
    }
    |> add_rule(rule_implementation)
    |> add_last_rule_results(rule_implementation)
    |> add_rule_results(rule_implementation)
  end

  defp add_rule(rule_implementation_mapping, rule_implementation) do
    case Ecto.assoc_loaded?(rule_implementation.rule) do
      true ->
        rule = rule_implementation.rule

        rule_mapping =
          %{
            name: rule.name,
            type_params: rule.type_params,
            minimum: rule.minimum,
            goal: rule.goal,
            result_type: rule.result_type
          }
          |> add_rule_type(rule)

        Map.put(rule_implementation_mapping, :rule, rule_mapping)

      _ ->
        rule_implementation_mapping
    end
  end

  defp add_rule_type(rule_mapping, rule) do
    case Ecto.assoc_loaded?(rule.rule_type) do
      true ->
        Map.put(rule_mapping, :rule_type, %{name: rule.rule_type.name})

      _ ->
        rule_mapping
    end
  end

  defp add_last_rule_results(rule_implementation_mapping, rule_implementation) do
    rule_results_mappings =
      case Map.get(rule_implementation, :_last_rule_result_, nil) do
        nil ->
          []

        last_rule_result ->
          [%{result: last_rule_result.result, date: last_rule_result.date, errors: last_rule_result.errors}]
      end

    rule_implementation_mapping
    |> Map.put(:rule_results, rule_results_mappings)
  end

  defp add_rule_results(rule_implementation_mapping, rule_implementation) do
    all_rule_results_mappings =
      rule_implementation
      |> Map.get(:all_rule_results, [])
      |> Enum.map(&%{result: &1.result, date: &1.date, records: &1.records, errors: &1.errors})

    case all_rule_results_mappings do
      [] -> rule_implementation_mapping
      _ -> Map.put(rule_implementation_mapping, :all_rule_results, all_rule_results_mappings)
    end
  end
end
