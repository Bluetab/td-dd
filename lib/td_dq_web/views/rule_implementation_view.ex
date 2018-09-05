defmodule TdDqWeb.RuleImplementationView do
  use TdDqWeb, :view
  alias TdDqWeb.RuleImplementationView

  def render("index.json", %{quality_rules: quality_rules} = assigns) do

    %{data: render_many(quality_rules,
      RuleImplementationView, "quality_rule.json",
      Map.drop(assigns, [:quality_rules]))
    }
  end

  def render("show.json", %{quality_rule: quality_rule} = assigns) do
    %{data: render_one(quality_rule,
      RuleImplementationView, "quality_rule.json",
      Map.drop(assigns, [:quality_rule]))
    }
  end

  def render("quality_rule.json", %{quality_rule: quality_rule} = assigns) do
    %{
      id: quality_rule.id,
      quality_control_id: quality_rule.quality_control_id,
      quality_rule_type_id: quality_rule.quality_rule_type_id,
      name: quality_rule.name,
      description: quality_rule.description,
      system: quality_rule.system,
      system_params: quality_rule.system_params,
      type: quality_rule.type,
      tag: quality_rule.tag
    }
    |> add_quality_rule_type(quality_rule)
    |> add_quality_control(quality_rule)
    |> add_quality_control_result(assigns)
  end

  defp add_quality_rule_type(quality_rule, qr) do
    case Ecto.assoc_loaded?(qr.quality_rule_type) do
      true ->
        quality_rule_type = %{
          id: qr.quality_rule_type.id,
          name: qr.quality_rule_type.name,
          params: qr.quality_rule_type.params
        }

        Map.put(quality_rule, :quality_rule_type, quality_rule_type)

      _ ->
        quality_rule
    end
  end

  defp add_quality_control(quality_rule, qr) do
    case Ecto.assoc_loaded?(qr.quality_control) do
      true ->
        quality_control = %{id: qr.quality_control.id, name: qr.quality_control.name}
        Map.put(quality_rule, :quality_control, quality_control)

      _ ->
        quality_rule
    end
  end

  defp add_quality_control_result(quality_rule, assigns) do
    case Map.get(assigns, :quality_controls_results) do
      nil -> quality_rule
      quality_controls_results ->
        case Map.get(quality_controls_results, quality_rule.id) do
          nil ->
            quality_rule
            |> Map.put(:results, [])
          quality_controls_result ->
            quality_rule
            |> Map.put(:results,
                  [%{result: quality_controls_result.result,
                     date: quality_controls_result.date}])
        end
    end
  end

end
