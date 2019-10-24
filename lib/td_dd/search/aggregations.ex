defmodule TdDd.Search.Aggregations do
  @moduledoc """
  Aggregations for elasticsearch
  """
  alias TdCache.TemplateCache

  def aggregation_terms do
    static_keywords = [
      {"ou.raw", %{terms: %{field: "ou.raw", size: 50}}},
      {"system.name.raw", %{terms: %{field: "system.name.raw", size: 50}}},
      {"group.raw", %{terms: %{field: "group.raw", size: 50}}},
      {"type.raw", %{terms: %{field: "type.raw", size: 50}}},
      {"confidential.raw", %{terms: %{field: "confidential.raw"}}},
      {"class.raw", %{terms: %{field: "class.raw"}}},
      {"field_type.raw", %{terms: %{field: "field_type.raw", size: 50}}}
    ]

    dynamic_keywords =
      TemplateCache.list_by_scope!("dd")
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

  def filter_content_term(%{"name" => "_confidential"}), do: true
  def filter_content_term(%{"values" => values}) when is_map(values), do: true
  def filter_content_term(_), do: false

  defp content_term(%{"name" => field, "type" => "user"}) do
    {field, %{terms: %{field: "df_content.#{field}.raw", size: 50}}}
  end

  defp content_term(%{"name" => field}) do
    {field, %{terms: %{field: "df_content.#{field}.raw"}}}
  end
end
