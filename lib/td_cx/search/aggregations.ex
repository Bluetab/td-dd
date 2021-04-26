defmodule TdCx.Search.Aggregations do
  @moduledoc """
  Aggregations for elasticsearch
  """

  def aggregation_terms do
    keywords = [
      {"source_external_id", %{terms: %{field: "source.external_id.raw", size: 50}}},
      {"source_type", %{terms: %{field: "source.type.raw", size: 50}}},
      {"status", %{terms: %{field: "status.raw", size: 50}}},
      {"type", %{terms: %{field: "type.raw", size: 50}}}
    ]

    Enum.into(keywords, %{})
  end
end
