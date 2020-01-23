defmodule TdCx.Search.Aggregations do
  @moduledoc """
  Aggregations for elasticsearch
  """

  def aggregation_terms do
    keywords = [
      {"source_type", %{terms: %{field: "source.type.raw", size: 50}}},
      {"job_status", %{terms: %{field: "status.raw", size: 50}}}
    ]

    Enum.into(keywords, %{})
  end
end
