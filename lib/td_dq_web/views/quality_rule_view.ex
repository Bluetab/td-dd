defmodule TdDqWeb.QualityRuleView do
  use TdDqWeb, :view
  alias TdDqWeb.QualityRuleView

  def render("index.json", %{quality_rules: quality_rules}) do
    %{data: render_many(quality_rules, QualityRuleView, "quality_rule.json")}
  end

  def render("show.json", %{quality_rule: quality_rule}) do
    %{data: render_one(quality_rule, QualityRuleView, "quality_rule.json")}
  end

  def render("quality_rule.json", %{quality_rule: quality_rule}) do
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
end
