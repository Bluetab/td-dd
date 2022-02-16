defmodule TdDq.Search.Aggregations do
  @moduledoc """
  Aggregations for elasticsearch
  """
  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdDfLib.Format

  def rule_aggregation_terms do
    static_keywords = [
      {"active.raw", %{terms: %{field: "active.raw"}}},
      {"current_business_concept_version",
       %{terms: %{field: "current_business_concept_version.name.raw", size: 50}}},
      # TODO: Avoid indexing domain parents
      {"taxonomy",
       %{
         nested: %{path: "domain_parents"},
         aggs: %{
           distinct_search: %{terms: %{field: "domain_parents.id", size: get_domains_count()}}
         }
       }}
    ]

    ["dq", "bg"]
    |> Enum.flat_map(&template_terms/1)
    |> Enum.concat(static_keywords)
    |> Enum.into(%{})
  end

  def implementation_aggregation_terms do
    static_keywords = [
      {"current_business_concept_version",
       %{terms: %{field: "current_business_concept_version.name.raw", size: 50}}},
      {"execution_result_info.result_text",
       %{terms: %{field: "execution_result_info.result_text.raw", size: 50}}},
      {"rule", %{terms: %{field: "rule.name.raw", size: 50}}},
      {"source_external_id", %{terms: %{field: "structure_aliases.raw", size: 50}}},
      {"taxonomy",
       %{
         nested: %{path: "domain_parents"},
         aggs: %{
           distinct_search: %{terms: %{field: "domain_parents.id", size: get_domains_count()}}
         }
       }},
      {"result_type.raw", %{terms: %{field: "result_type.raw"}}}
    ]

    ["dq", "bg", "ri"]
    |> Enum.flat_map(&template_terms/1)
    |> Enum.concat(static_keywords)
    |> Enum.into(%{})
  end

  defp template_terms(scope) do
    scope
    |> TemplateCache.list_by_scope!()
    |> Enum.flat_map(&template_terms(&1, scope))
    |> Enum.uniq()
  end

  defp template_terms(%{content: content}, scope) do
    content
    |> Format.flatten_content_fields()
    |> Enum.filter(&filter_content_term/1)
    |> Enum.map(&Map.take(&1, ["name", "type"]))
    |> Enum.reject(&(scope == "bg" and &1["type"] != "user"))
    |> Enum.map(&content_term(&1, scope))
  end

  defp filter_content_term(%{"type" => "domain"}), do: true
  defp filter_content_term(%{"type" => "system"}), do: true
  defp filter_content_term(%{"values" => values}) when is_map(values), do: true
  defp filter_content_term(_), do: false

  defp content_term(%{"name" => field, "type" => "user"}, "dq") do
    {field, %{terms: %{field: "df_content.#{field}.raw", size: 50}}}
  end

  defp content_term(%{"name" => field, "type" => type}, "dq") when type in ["domain", "system"] do
    {field,
     %{
       nested: %{path: "df_content.#{field}"},
       aggs: %{
         distinct_search: %{terms: %{field: "df_content.#{field}.external_id.raw", size: 50}}
       }
     }}
  end

  defp content_term(%{"name" => field}, "dq") do
    {field, %{terms: %{field: "df_content.#{field}.raw"}}}
  end

  defp content_term(%{"name" => field}, "ri") do
    {field, %{terms: %{field: "df_content.#{field}.raw"}}}
  end

  defp content_term(%{"name" => field, "type" => "user"}, "bg") do
    {field, %{terms: %{field: "current_business_concept_version.content.#{field}.raw", size: 50}}}
  end

  defp get_domains_count do
    case TaxonomyCache.domain_count() do
      0 -> 10
      count -> count
    end
  end
end
