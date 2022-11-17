defmodule TdCx.Search.Mappings do
  @moduledoc """
  Generates mappings for elasticsearch
  """

  @raw_sort %{raw: %{type: "keyword"}, sort: %{type: "keyword", normalizer: "sortable"}}

  alias TdDd.Search.Cluster

  def get_mappings do
    mapping_type = %{
      id: %{type: "long"},
      source_id: %{type: "long"},
      external_id: %{type: "text", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      source: %{
        properties: %{
          external_id: %{type: "text", fields: @raw_sort},
          type: %{type: "text", fields: @raw_sort}
        }
      },
      start_date: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      end_date: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      status: %{type: "text", fields: @raw_sort},
      type: %{type: "text", fields: @raw_sort},
      message: %{type: "text"}
    }

    settings = Cluster.setting(:jobs)

    %{mappings: %{properties: mapping_type}, settings: settings}
  end
end
