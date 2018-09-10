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

  defp add_rule(rule_implementation, qr) do
    case Ecto.assoc_loaded?(qr.rule) do
      true ->
        rule = qr.rule
        rule_map = %{id: rule.id, name: rule.name}
        |> add_rule_type(rule)
        Map.put(rule_implementation, :rule, rule_map)

      _ ->
        rule_implementation
    end
  end

  defp add_rule_type(rule_implementation, qr) do
    case Ecto.assoc_loaded?(qr.rule_type) do
      true ->
        rule_type = %{
          id: qr.rule_type.id,
          name: qr.rule_type.name,
          params: qr.rule_type.params
        }

        Map.put(rule_implementation, :rule_type, rule_type)

      _ ->
        rule_implementation
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
