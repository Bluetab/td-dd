defmodule TdDd.Search.Aggregations do
  @moduledoc """
    Aggregations for elasticsearch
  """

  def aggregation_terms do
    static_keywords = [
      {"ou", %{terms: %{field: "ou"}}}
    ]

    static_keywords
      |> Enum.into(%{})
  end

end
