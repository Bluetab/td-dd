defmodule TdDqWeb.SegmentResultView do
  use TdDqWeb, :view

  def render("index.json", %{segment_results: segment_results}) do
    %{data: render_many(segment_results, __MODULE__, "segment_result.json")}
  end

  def render("segment_result.json", %{rule: %{} = rule} = assigns) do
    rule_props =
      rule
      |> Map.take([:result_type, :minimum, :goal])
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    "segment_result.json"
    |> render(Map.delete(assigns, :rule))
    |> Map.merge(rule_props)
  end

  def render("segment_result.json", %{segment_result: segment_result}) do
    segment_result
    |> Map.take([
      :id,
      :date,
      :result,
      :records,
      :errors,
      :result_type,
      :details,
      :parent_id,
      :updated_at,
      :inserted_at
    ])
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
    |> with_params(segment_result)
  end

  defp with_params(map, %{params: %{} = params}) when params != %{} do
    Map.put(map, :params, params)
  end

  defp with_params(map, _), do: map
end
