defmodule TdDqWeb.RuleResultView do
  use TdDqWeb, :view

  alias TdDqWeb.RuleResultView

  def render("index.json", %{rule_results: rule_results}) do
    %{data: render_many(rule_results, RuleResultView, "rule_result.json")}
  end

  def render("rule_result.json", %{rule: %{} = rule} = assigns) do
    rule_props =
      rule
      |> Map.take([:result_type, :minimum, :goal])
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    "rule_result.json"
    |> render(Map.delete(assigns, :rule))
    |> Map.merge(rule_props)
  end

  def render("rule_result.json", %{rule_result: rule_result}) do
    rule_result
    |> Map.take([:id, :implementation_key, :date, :result, :records, :errors, :result_type])
    |> with_params(rule_result)
  end

  defp with_params(map, %{params: %{} = params}) when params != %{} do
    Map.put(map, :params, params)
  end

  defp with_params(map, _), do: map
end
