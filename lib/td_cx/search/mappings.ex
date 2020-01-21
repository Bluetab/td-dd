defmodule TdCx.Search.Mappings do
  @moduledoc """
  Generates mappings for elasticsearch
  """

  @raw %{raw: %{type: "keyword"}}
  @raw_sort %{raw: %{type: "keyword"}, sort: %{type: "keyword", normalizer: "sortable"}}

  def get_mappings do
    mapping_type = %{
      id: %{type: "long"},
      exteral_id: %{type: "text", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      source: %{
        properties: %{
          external_id: %{type: "text"},
          type: %{type: "text", fields: @raw}
        }
      },
      start: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      end: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      status: %{type: "text", fields: @raw_sort},
      message: %{type: "text", fields: @raw}
    }

    settings = %{
      number_of_shards: 1,
      analysis: %{
        normalizer: %{
          sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
        }
      }
    }

    %{mappings: %{_doc: %{properties: mapping_type}}, settings: settings}
  end
end
