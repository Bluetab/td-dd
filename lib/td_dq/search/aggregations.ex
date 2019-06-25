defmodule TdDq.Search.Aggregations do
  @moduledoc """
    Aggregations for elasticsearch
  """
  @df_cache Application.get_env(:td_dq, :df_cache)

  def aggregation_terms do
    static_keywords = [
      {"active.raw", %{terms: %{field: "active.raw"}}},
      {"domain_parents",
       %{
         nested: %{path: "domain_parents"},
         aggs: %{distinct_search: %{terms: %{field: "domain_parents.name.raw", size: 50}}}
       }},
      {"population.raw", %{terms: %{field: "group.raw", size: 50}}},
      {"priority.raw", %{terms: %{field: "type.raw", size: 50}}},
      {"rule_type", %{terms: %{field: "rule_type.name.raw", size: 50}}},
      {"current_business_concept_version",
       %{terms: %{field: "current_business_concept_version.name.raw", size: 50}}},
      {"execution_result_info.result_text",
       %{terms: %{field: "execution_result_info.result_text.raw", size: 50}}}
    ]

    dynamic_keywords =
      @df_cache.list_templates_by_scope("dq")
      |> Enum.flat_map(&template_terms/1)

    (static_keywords ++ dynamic_keywords)
    |> Enum.into(%{})
  end

  def template_terms(%{content: content}) do
    content
    |> Enum.filter(&filter_content_term/1)
    |> Enum.map(& &1["name"])
    |> Enum.map(&content_term/1)
  end

  def filter_content_term(%{"values" => values}) when is_map(values), do: true
  def filter_content_term(_), do: false

  defp content_term(field) do
    {field, %{terms: %{field: "df_content.#{field}.raw"}}}
  end
end
