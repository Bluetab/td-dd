defmodule TdDqWeb.RuleResultView do
  use TdDqWeb, :view

  def render("show.json", %{rule_result: rule_result}) do
    %{data: render_one(rule_result, __MODULE__, "rule_result.json")}
  end

  def render("index.json", %{rule_results: rule_results}) do
    %{data: render_many(rule_results, __MODULE__, "rule_result.json")}
  end

  def render("index.json", %{segment_results: segment_results}) do
    %{data: render_many(segment_results, __MODULE__, "rule_result.json")}
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
    |> Map.take([
      :id,
      :implementation_id,
      :date,
      :result,
      :records,
      :errors,
      :result_type,
      :execution_id,
      :details,
      :segments_inserted,
      :has_segments,
      :updated_at
    ])
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
    |> with_has_remediation(rule_result)
    |> with_params(rule_result)
  end

  defp with_params(map, %{params: %{} = params}) when params != %{} do
    Map.put(map, :params, params)
  end

  defp with_params(map, _), do: map

  defp with_has_remediation(map, %{remediation: remediation} = _rule_result) do
    Map.put(map, :has_remediation, not is_nil(remediation))
  end

  defp with_has_remediation(map, _), do: map
end
