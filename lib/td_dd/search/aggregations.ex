defmodule TdDd.Search.Aggregations do
  @moduledoc """
    Aggregations for elasticsearch
  """

  def aggregation_terms do
    static_keywords = [
      {"ou.raw", %{terms: %{field: "ou.raw"}}},
      {"system.raw", %{terms: %{field: "system.raw"}}},
      {"name.raw", %{terms: %{field: "name.raw"}}},
      {"group.raw", %{terms: %{field: "group.raw"}}}
    ]

    static_keywords
      |> Enum.into(%{})
  end

end
