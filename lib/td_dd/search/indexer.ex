defmodule TdDd.Search.Indexer do
  @moduledoc """
    Manages elasticsearch indices
  """
  alias TdDd.ESClientApi
  alias TdDd.Search

  def reindex(:data_structure) do
    ESClientApi.delete!("data_structure")
    mapping = get_mappings() |> Poison.encode!()
    ESClientApi.put!("data_structure", mapping)
    Search.put_bulk_search(:data_structure)
  end

  defp get_mappings do
    mapping_type = %{
      id: %{type: "long"},
      name: %{type: "text"},
      system: %{type: "text"},
      group: %{type: "text"},
      type: %{type: "text"},
      ou: %{type: "text"},
      lopd: %{type: "text"},
      description: %{type: "text"},
      last_change_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      last_change_by: %{
        properties: %{
          id: %{type: "long"},
          user_name: %{type: "text", fields: %{raw: %{type: "keyword"}}},
          full_name: %{type: "text", fields: %{raw: %{type: "keyword"}}}
        }
      }
    }
    %{mappings: %{doc: %{properties: mapping_type}}}
  end

end
