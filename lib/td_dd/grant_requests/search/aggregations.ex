defmodule TdDd.GrantRequests.Search.Aggregations do
  @moduledoc """
  Support for grant request search aggregations
  """

  alias TdCache.TemplateCache
  alias TdDfLib.Format

  def aggregations do
    static_aggs = %{
      "user" => %{terms: %{field: "user.user_name"}},
      "current_status" => %{terms: %{field: "current_status"}},
      "taxonomy" => %{terms: %{field: "domain_ids", size: 500}},
      "type" => %{terms: %{field: "type"}}
    }

    gr_terms =
      TemplateCache.list_by_scope!("gr")
      |> Enum.flat_map(&content_terms/1)
      |> Map.new()
      |> Map.merge(static_aggs)

    TemplateCache.list_by_scope!("dd")
    |> Enum.flat_map(&dsv_content_terms/1)
    |> Map.new()
    |> Map.merge(gr_terms)
  end

  defp content_terms(%{content: content}) do
    content
    |> Format.flatten_content_fields()
    |> Enum.flat_map(fn
      %{"name" => field, "type" => "domain"} ->
        [{field, %{terms: %{field: "metadata.#{field}", size: 50}, meta: %{type: "domain"}}}]

      %{"name" => field, "type" => "hierarchy"} ->
        [{field, %{terms: %{field: "metadata.#{field}.raw"}, meta: %{type: "hierarchy"}}}]

      %{"name" => field, "type" => "system"} ->
        [{field, nested_agg(field)}]

      %{"name" => field, "type" => "user"} ->
        [{field, %{terms: %{field: "metadata.#{field}.raw", size: 50}}}]

      %{"name" => field, "values" => %{}} ->
        [{field, %{terms: %{field: "metadata.#{field}.raw"}}}]

      _ ->
        []
    end)
  end

  defp dsv_content_terms(%{content: content}) do
    content
    |> Format.flatten_content_fields()
    |> Enum.flat_map(fn
      %{"name" => field, "type" => "domain"} ->
        [
          {field,
           %{
             terms: %{field: "data_structure_version.note.#{field}", size: 50},
             meta: %{type: "domain"}
           }}
        ]

      %{"name" => field, "type" => "hierarchy"} ->
        [
          {field,
           %{
             terms: %{field: "data_structure_version.note.#{field}.raw"},
             meta: %{type: "hierarchy"}
           }}
        ]

      %{"name" => field, "type" => "system"} ->
        [{field, dsv_nested_agg(field)}]

      %{"name" => field, "type" => "user"} ->
        [{field, %{terms: %{field: "data_structure_version.note.#{field}.raw", size: 50}}}]

      %{"name" => field, "values" => %{}} ->
        [{field, %{terms: %{field: "data_structure_version.note.#{field}.raw"}}}]

      _ ->
        []
    end)
  end

  defp nested_agg(field) do
    %{
      nested: %{path: "metadata.#{field}"},
      aggs: %{
        distinct_search: %{
          terms: %{field: "metadata.#{field}.external_id.raw"}
        }
      }
    }
  end

  defp dsv_nested_agg(field) do
    %{
      nested: %{path: "data_structure_version.note.#{field}"},
      aggs: %{
        distinct_search: %{
          terms: %{field: "data_structure_version.note.#{field}.external_id.raw"}
        }
      }
    }
  end
end
