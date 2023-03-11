defmodule TdDq.Implementations.Search.Aggregations do
  @moduledoc """
  Support for rule implementation search aggregations
  """

  alias TdCache.TemplateCache
  alias TdDfLib.Format

  def aggregations do
    static_aggs = %{
      "execution_result_info.result_text" => %{
        terms: %{field: "execution_result_info.result_text.raw", size: 50}
      },
      "rule" => %{terms: %{field: "rule.name.raw", size: 50}},
      "source_external_id" => %{terms: %{field: "structure_aliases.raw", size: 50}},
      "status" => %{terms: %{field: "status"}},
      "result_type.raw" => %{terms: %{field: "result_type.raw"}},
      "taxonomy" => %{terms: %{field: "domain_ids", size: 500}}
    }

    TemplateCache.list_by_scope!("ri")
    |> Enum.flat_map(&content_terms/1)
    |> Map.new()
    |> Map.merge(static_aggs)
  end

  defp content_terms(%{content: content}) do
    content
    |> Format.flatten_content_fields()
    |> Enum.flat_map(fn
      %{"name" => field, "type" => "domain"} ->
        [{field, %{terms: %{field: "df_content.#{field}", size: 50}, meta: %{type: "domain"}}}]

      %{"name" => field, "type" => "hierarchy"} ->
        [{field, %{terms: %{field: "df_content.#{field}.raw"}, meta: %{type: "hierarchy"}}}]

      %{"name" => field, "type" => "system"} ->
        [{field, nested_agg(field)}]

      %{"name" => field, "type" => "user"} ->
        [{field, %{terms: %{field: "df_content.#{field}.raw"}}}]

      %{"name" => field, "values" => %{}} ->
        [{field, %{terms: %{field: "df_content.#{field}.raw"}}}]

      _ ->
        []
    end)
  end

  defp nested_agg(field) do
    %{
      nested: %{path: "df_content.#{field}"},
      aggs: %{distinct_search: %{terms: %{field: "df_content.#{field}.external_id.raw"}}}
    }
  end
end
