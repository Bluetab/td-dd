defmodule TdDd.Search.Indexer do
  @moduledoc """
    Manages elasticsearch indices
  """
  alias TdDd.ESClientApi
  alias TdDd.Search

  @df_cache Application.get_env(:td_dd, :df_cache)

  def reindex(:data_structure) do
    ESClientApi.delete!("data_structure")
    mapping = get_mappings() |> Poison.encode!()
    %{status_code: 200} = ESClientApi.put!("data_structure", mapping)
    Search.put_bulk_search(:data_structure)
  end

  defp get_mappings do
    content_mappings = %{properties: get_dynamic_mappings()}

    mapping_type = %{
      id: %{type: "long"},
      name: %{type: "text", fields: %{raw: %{type: "keyword"}}},
      system: %{type: "text", fields: %{raw: %{type: "keyword"}}},
      group: %{type: "text", fields: %{raw: %{type: "keyword"}}},
      ou: %{type: "text", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      type: %{type: "text", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      description: %{type: "text", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      domain_ids: %{type: "long"},
      last_change_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      last_change_by: %{
        properties: %{
          id: %{type: "long"},
          user_name: %{type: "text", fields: %{raw: %{type: "keyword"}}},
          full_name: %{type: "text", fields: %{raw: %{type: "keyword"}}}
        }
      },
      inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      data_fields: %{
        properties: %{
          name: %{type: "text"},
          business_concept_id: %{type: "text"},
          data_structure_id: %{type: "long"},
          description: %{type: "text"},
          id: %{type: "long"}
        }
      },
      df_content: content_mappings
    }
    settings = %{analysis: %{normalizer: %{sortable: %{type: "custom", char_filter: [], filter: ["asciifolding"]}}}}
    %{mappings: %{doc: %{properties: mapping_type}}, settings: settings}
  end

  def get_dynamic_mappings do
    @df_cache.list_templates()
    |> Enum.flat_map(&get_mappings/1)
    |> Enum.into(%{})
    |> Map.put("_confidential", %{type: "text", fields: %{raw: %{type: "keyword"}}})
  end

  defp get_mappings(%{content: content}) do
    content
    |> Enum.map(&field_mapping/1)
  end

  defp field_mapping(%{"name" => name, "type" => type}) do
    {name, mapping_type(type)}
  end

  defp field_mapping(%{"name" => name}) do
    {name, mapping_type("string")}
  end

  defp mapping_type("list") do
    %{type: "text", fields: %{raw: %{type: "keyword"}}}
  end

  defp mapping_type(_default), do: %{type: "text"}
end
