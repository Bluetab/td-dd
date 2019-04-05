defmodule TdDd.Search.Aggregations do
  @moduledoc """
    Aggregations for elasticsearch
  """
  @df_cache Application.get_env(:td_dd, :df_cache)

  def aggregation_terms do
    static_keywords = [
      {"ou.raw", %{terms: %{field: "ou.raw", size: 50}}},
      {"system.name.raw", %{terms: %{field: "system.name.raw", size: 50}}},
      {"group.raw", %{terms: %{field: "group.raw", size: 50}}},
      {"type.raw", %{terms: %{field: "type.raw", size: 50}}},
      {"confidential.raw", %{terms: %{field: "confidential.raw"}}}
    ]

    dynamic_keywords =
      @df_cache.list_templates()
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

  def filter_content_term(%{"type" => "list"}), do: true
  def filter_content_term(_), do: false

  defp content_term(field) do
    {field, %{terms: %{field: "df_content.#{field}.raw"}}}
  end
end
