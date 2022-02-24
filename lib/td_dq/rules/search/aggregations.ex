defmodule TdDq.Rules.Search.Aggregations do
  @moduledoc """
  Support for rule search aggregations
  """

  alias TdCache.TemplateCache
  alias TdDfLib.Format

  def aggregations do
    static_aggs = %{
      "active.raw" => %{terms: %{field: "active.raw"}},
      # TODO: Avoid indexing domain parents
      "taxonomy" => %{
        nested: %{path: "domain_parents"},
        aggs: %{
          distinct_search: %{terms: %{field: "domain_parents.id", size: 500}}
        }
      }
    }

    TemplateCache.list_by_scope!("dq")
    |> Enum.flat_map(&content_terms/1)
    |> Map.new()
    |> Map.merge(static_aggs)
  end

  defp content_terms(%{content: content}) do
    content
    |> Format.flatten_content_fields()
    |> Enum.flat_map(fn
      %{"name" => field, "type" => type} when type in ["domain", "system"] ->
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
