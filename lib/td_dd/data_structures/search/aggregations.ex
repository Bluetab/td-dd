defmodule TdDd.DataStructures.Search.Aggregations do
  @moduledoc """
  Aggregations for elasticsearch
  """
  alias TdCache.TemplateCache
  alias TdDd.DataStructures.CatalogViewConfigs
  alias TdDd.DataStructures.DataStructureTypes
  alias TdDfLib.Format

  @missing_term_name "_missing"

  def missing_term_name, do: @missing_term_name

  def aggregations do
    static_aggs = %{
      "system.name.raw" => %{terms: %{field: "system.name.raw", size: 500}},
      "group.raw" => %{terms: %{field: "group.raw", size: 50}},
      "type.raw" => %{terms: %{field: "type.raw", size: 50}},
      "confidential.raw" => %{terms: %{field: "confidential.raw"}},
      "class.raw" => %{terms: %{field: "class.raw"}},
      "field_type.raw" => %{terms: %{field: "field_type.raw", size: 50}},
      "with_content.raw" => %{terms: %{field: "with_content.raw"}},
      "tags.raw" => %{terms: %{field: "tags.raw", size: 50}},
      "linked_concepts" => %{terms: %{field: "linked_concepts"}},
      "taxonomy" => %{terms: %{field: "domain_ids", size: 500}},
      "with_profiling.raw" => %{terms: %{field: "with_profiling.raw"}}
    }

    filters = filter_aggs()

    TemplateCache.list_by_scope!("dd")
    |> Enum.flat_map(&content_terms/1)
    |> Map.new()
    |> Map.merge(static_aggs)
    |> Map.merge(filters)
  end

  defp filter_aggs do
    catalog_view_configs_filters =
      CatalogViewConfigs.list()
      |> Enum.filter(&(&1.field_type == "note"))
      |> Enum.map(fn
        %{field_type: "note", field_name: field_name} ->
          {"note.#{field_name}",
           %{
             terms: %{
               field: "note.#{field_name}.raw",
               missing: @missing_term_name
             }
           }}
      end)
      |> Map.new()

    data_structure_types_filters =
      DataStructureTypes.metadata_filters()
      |> Map.values()
      |> List.flatten()
      |> Enum.uniq()
      |> Map.new(fn filter ->
        {"metadata.#{filter}",
         %{terms: %{field: "_filters.#{filter}", missing: @missing_term_name}}}
      end)

    Map.merge(catalog_view_configs_filters, data_structure_types_filters)
  end

  defp content_terms(%{content: content}) do
    content
    |> Format.flatten_content_fields()
    |> Enum.flat_map(fn
      %{"name" => field, "type" => "domain"} ->
        [{field, %{terms: %{field: "note.#{field}", size: 50}, meta: %{type: "domain"}}}]

      %{"name" => field, "type" => "hierarchy"} ->
        [{field, %{terms: %{field: "note.#{field}.raw"}, meta: %{type: "hierarchy"}}}]

      %{"name" => field, "type" => "system"} ->
        [{field, nested_agg(field)}]

      %{"name" => field, "type" => "user"} ->
        [{field, %{terms: %{field: "note.#{field}.raw", size: 50}}}]

      %{"name" => field, "values" => %{}} ->
        [{field, %{terms: %{field: "note.#{field}.raw"}}}]

      _ ->
        []
    end)
  end

  defp nested_agg(field) do
    %{
      nested: %{path: "note.#{field}"},
      aggs: %{distinct_search: %{terms: %{field: "note.#{field}.external_id.raw"}}}
    }
  end
end
