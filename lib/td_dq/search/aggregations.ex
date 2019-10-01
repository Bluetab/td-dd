defmodule TdDq.Search.Aggregations do
  @moduledoc """
  Aggregations for elasticsearch
  """
  alias TdCache.TemplateCache

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
      {"type_params", %{terms: %{field: "type_params.name.raw", size: 50}}},
      {"users_roles", %{terms: %{field: "users_roles.raw", size: 50}}},
      {"current_business_concept_version",
       %{terms: %{field: "current_business_concept_version.name.raw", size: 50}}},
      {"execution_result_info.result_text",
       %{terms: %{field: "execution_result_info.result_text.raw", size: 50}}},
      {"execution.raw", %{terms: %{field: "execution.raw"}}}
    ]

    dynamic_keywords =
      TemplateCache.list_by_scope!("dq")
      |> Enum.flat_map(&template_terms/1)

    (static_keywords ++ dynamic_keywords)
    |> Enum.into(%{})
  end

  def template_terms(%{content: content}) do
    content
    |> Enum.filter(&filter_content_term/1)
    |> Enum.map(&Map.take(&1, ["name", "type"]))
    |> Enum.map(&content_term/1)
  end

  def filter_content_term(%{"values" => values}) when is_map(values), do: true
  def filter_content_term(_), do: false

  defp content_term(%{"name" => field, "type" => "user"}) do
    {field, %{terms: %{field: "df_content.#{field}.raw", size: 50}}}
  end

  defp content_term(%{"name" => field}) do
    {field, %{terms: %{field: "df_content.#{field}.raw"}}}
  end
end
