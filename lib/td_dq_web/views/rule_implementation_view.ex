defmodule TdDqWeb.RuleImplementationView do
  use TdDqWeb, :view
  alias TdDqWeb.RuleImplementationView

  def render("index.json", %{rule_implementations: rule_implementations} = assigns) do

    %{data: render_many(rule_implementations,
      RuleImplementationView, "rule_implementation.json",
      Map.drop(assigns, [:rule_implementations]))
    }
  end

  def render("show.json", %{rule_implementation: rule_implementation} = assigns) do
    %{data: render_one(rule_implementation,
      RuleImplementationView, "rule_implementation.json",
      Map.drop(assigns, [:rule_implementation]))
    }
  end

  def render("rule_implementation.json", %{rule_implementation: rule_implementation} = assigns) do
    %{
      id: rule_implementation.id,
      rule_id: rule_implementation.rule_id,
      name: rule_implementation.name,
      description: rule_implementation.description,
      system: rule_implementation.system,
      system_params: rule_implementation.system_params,
      tag: rule_implementation.tag
    }
    |> add_rule(rule_implementation)
    |> add_rule_result(assigns)
  end

  defp add_rule(rule_implementation_mapping, rule_implementation) do
    case Ecto.assoc_loaded?(rule_implementation.rule) do
      true ->
        rule = rule_implementation.rule
        rule_mapping = %{name: rule.name}
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

  defp add_rule_result(rule_implementation, assigns) do
    case Map.get(assigns, :rules_results) do
      nil -> rule_implementation
      rules_results ->
        case Map.get(rules_results, rule_implementation.id) do
          nil ->
            rule_implementation
            |> Map.put(:results, [])
          rules_result ->
            rule_implementation
            |> Map.put(:results,
                  [%{result: rules_result.result,
                     date: rules_result.date}])
        end
    end
  end

end
