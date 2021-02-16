defmodule TdDd.Search.Aggregations do
  @moduledoc """
  Aggregations for elasticsearch
  """
  alias TdCache.TemplateCache
  alias TdDfLib.Format

  def aggregation_terms do
    # TODO: Config aggregations
    static_keywords = [
      {"system.name.raw", %{terms: %{field: "system.name.raw", size: 50}}},
      {"domain.name.raw", %{terms: %{field: "domain.name.raw", size: 50}}},
      {"group.raw", %{terms: %{field: "group.raw", size: 50}}},
      {"type.raw", %{terms: %{field: "type.raw", size: 50}}},
      {"confidential.raw", %{terms: %{field: "confidential.raw"}}},
      {"class.raw", %{terms: %{field: "class.raw"}}},
      {"field_type.raw", %{terms: %{field: "field_type.raw", size: 50}}},
      {"with_content.raw", %{terms: %{field: "with_content.raw"}}},
      {"linked_concepts_count",
       %{terms: %{script: "doc['linked_concepts_count'].value > 0 ? 'linked' : 'unlinked'"}}}
    ]

    dynamic_keywords =
      TemplateCache.list_by_scope!("dd")
      |> Enum.flat_map(&template_terms/1)

    (static_keywords ++ dynamic_keywords)
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

  def template_terms(%{content: content}) do
    content
    |> Format.flatten_content_fields()
    |> Enum.filter(&filter_content_term/1)
    |> Enum.map(&Map.take(&1, ["name", "type"]))
    |> Enum.map(&content_term/1)
  end

  defp filter_content_term(%{"name" => "_confidential"}), do: true
  defp filter_content_term(%{"type" => "domain"}), do: true
  defp filter_content_term(%{"type" => "system"}), do: true
  defp filter_content_term(%{"values" => values}) when is_map(values), do: true
  defp filter_content_term(_), do: false

  defp content_term(%{"name" => field, "type" => "user"}) do
    {field, %{terms: %{field: "df_content.#{field}.raw", size: 50}}}
  end

  defp content_term(%{"name" => field, "type" => type}) when type in ["domain", "system"] do
    {field,
     %{
       nested: %{path: "df_content.#{field}"},
       aggs: %{
         distinct_search: %{terms: %{field: "df_content.#{field}.external_id.raw", size: 50}}
       }
     }}
  end

  defp content_term(%{"name" => field}) do
    {field, %{terms: %{field: "df_content.#{field}.raw"}}}
  end
end
