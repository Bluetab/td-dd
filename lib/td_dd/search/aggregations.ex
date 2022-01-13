defmodule TdDd.Search.Aggregations do
  @moduledoc """
  Aggregations for elasticsearch
  """
  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdDfLib.Format

  def aggregation_terms do
    static_keywords = [
      {"system.name.raw", %{terms: %{field: "system.name.raw", size: 50}}},
      {"group.raw", %{terms: %{field: "group.raw", size: 50}}},
      {"type.raw", %{terms: %{field: "type.raw", size: 50}}},
      {"confidential.raw", %{terms: %{field: "confidential.raw"}}},
      {"class.raw", %{terms: %{field: "class.raw"}}},
      {"field_type.raw", %{terms: %{field: "field_type.raw", size: 50}}},
      {"with_content.raw", %{terms: %{field: "with_content.raw"}}},
      {"tags.raw", %{terms: %{field: "tags.raw", size: 50}}},
      {"linked_concepts_count",
       %{terms: %{script: "doc['linked_concepts_count'].value > 0 ? 'linked' : 'unlinked'"}}},
      {"taxonomy",
       %{
         nested: %{path: "domain_parents"},
         aggs: %{
           distinct_search: %{terms: %{field: "domain_parents.id", size: get_domains_count()}}
         }
       }},
      {"with_profiling.raw", %{terms: %{field: "with_profiling.raw"}}},
      {"has_field_child.raw", %{terms: %{field: "has_field_child.raw"}}}
    ]

    ["dd", "cx"]
    |> Enum.flat_map(&template_terms/1)
    |> Enum.concat(static_keywords)
    |> Enum.into(%{})
  end

  def grant_aggregation_terms do
    static_keywords = [
      {"taxonomy",
       %{
         nested: %{path: "data_structure_version.domain_parents"},
         aggs: %{
           distinct_search: %{
             terms: %{field: "data_structure_version.domain_parents.id", size: 50}
           }
         }
       }},
      {"type.raw", %{terms: %{field: "data_structure_version.type.raw", size: 50}}}
    ]

    static_keywords
    |> Enum.into(%{})
  end

  def get_agg_terms([]) do
    nil
  end

  def get_agg_terms([agg_definition | agg_defs]) do
    %{"agg_name" => agg_name, "field_name" => field_name} = agg_definition
    new_term_value = %{terms: %{field: field_name, size: 50}}

    new_term_value =
      case agg_defs do
        [] ->
          new_term_value

        _ ->
          new_agg_term_aggs = get_agg_terms(agg_defs)
          Map.put(new_term_value, "aggs", new_agg_term_aggs)
      end

    %{agg_name => new_term_value}
  end

  def get_agg_term(agg_name, field_name) do
    Map.put(%{}, agg_name, %{terms: %{field: field_name}})
  end

  defp template_terms(scope) do
    scope
    |> TemplateCache.list_by_scope!()
    |> Enum.flat_map(&template_terms(&1, scope))
    |> Enum.uniq()
  end

  def template_terms(%{content: content}, scope) do
    content
    |> Format.flatten_content_fields()
    |> Enum.filter(&filter_content_term/1)
    |> Enum.map(&Map.take(&1, ["name", "type"]))
    |> Enum.reject(&(scope == "cx" and &1["type"] in ["domain", "system"]))
    |> Enum.map(&content_term(&1, scope))
  end

  defp filter_content_term(%{"name" => "_confidential"}), do: true
  defp filter_content_term(%{"type" => "domain"}), do: true
  defp filter_content_term(%{"type" => "system"}), do: true
  defp filter_content_term(%{"values" => values}) when is_map(values), do: true
  defp filter_content_term(_), do: false

  defp content_term(%{"name" => field, "type" => "user"}, "dd") do
    {field, %{terms: %{field: "latest_note.#{field}.raw", size: 50}}}
  end

  defp content_term(%{"name" => field, "type" => type}, "dd") when type in ["domain", "system"] do
    {field,
     %{
       nested: %{path: "latest_note.#{field}"},
       aggs: %{
         distinct_search: %{terms: %{field: "latest_note.#{field}.external_id.raw", size: 50}}
       }
     }}
  end

  defp content_term(%{"name" => field}, "dd") do
    {field, %{terms: %{field: "latest_note.#{field}.raw"}}}
  end

  defp content_term(%{"name" => field, "type" => "user"}, "cx") do
    {field, %{terms: %{field: "source.config.#{field}.raw", size: 50}}}
  end

  defp content_term(%{"name" => field, "type" => type}, "cx") when type in ["domain", "system"] do
    {field,
     %{
       nested: %{path: "source.config.#{field}"},
       aggs: %{
         distinct_search: %{terms: %{field: "source.config.#{field}.external_id.raw", size: 50}}
       }
     }}
  end

  defp content_term(%{"name" => field}, "cx") do
    {field, %{terms: %{field: "source.config.#{field}.raw"}}}
  end

  defp get_domains_count do
    case Enum.count(TaxonomyCache.get_domain_ids()) do
      0 -> 10
      count -> count
    end
  end
end
