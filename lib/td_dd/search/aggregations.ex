defmodule TdDd.Search.Aggregations do
  @moduledoc """
    Aggregations for elasticsearch
  """

  def aggregation_terms do
    static_keywords = [
      {"ou.raw", %{terms: %{field: "ou.raw"}}}
    ]

    static_keywords
      |> Enum.into(%{})
  end

end
