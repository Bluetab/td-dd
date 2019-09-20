defmodule TdDd.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """
  alias Jason, as: JSON
  alias TdCache.TemplateCache
  alias TdDd.ESClientApi
  alias TdDd.Search

  def reindex(:all) do
    ESClientApi.delete!("data_structure")
    mapping = get_mappings() |> JSON.encode!()
    %{status_code: 200} = ESClientApi.put!("data_structure", mapping)
    Search.put_bulk_search(:all)
  end

  def reindex(ids) do
    Search.put_bulk_search(ids)
  end

  defp get_mappings do
    content_mappings = %{properties: get_dynamic_mappings()}

    mapping_type = %{
      id: %{type: "long", index: false},
      name: %{type: "text", boost: 2, fields: %{raw: %{type: "keyword"}}},
      system: %{
        properties: %{
          id: %{type: "long", index: false},
          external_id: %{type: "text", fields: %{raw: %{type: "keyword"}}},
          name: %{type: "text", fields: %{raw: %{type: "keyword"}}}
        }
      },
      group: %{type: "text", fields: %{raw: %{type: "keyword"}}},
      ou: %{type: "text", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      type: %{type: "text", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      confidential: %{type: "boolean", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      description: %{type: "text", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      external_id: %{type: "keyword", index: false},
      domain_ids: %{type: "long"},
      deleted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      last_change_by: %{enabled: false},
      inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      updated_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      data_fields: %{
        properties: %{
          name: %{type: "text"},
          description: %{type: "text"},
          id: %{type: "long", index: false}
        }
      },
      ancestry: %{enabled: false},
      df_content: content_mappings,
      status: %{type: "keyword", null_value: ""},
      class: %{
        type: "text",
        fields: %{
          raw: %{
            type: "keyword",
            null_value: ""
          }
        }
      }
    }

    settings = %{
      analysis: %{
        normalizer: %{sortable: %{type: "custom", char_filter: [], filter: ["asciifolding"]}}
      }
    }

    %{mappings: %{doc: %{properties: mapping_type}}, settings: settings}
  end

  def get_dynamic_mappings do
    TemplateCache.list_by_scope!("dd")
    |> Enum.flat_map(&get_mappings/1)
    |> Enum.into(%{})
  end

  defp get_mappings(%{content: content}) do
    content
    |> Enum.filter(&(Map.get(&1, "type") != "url"))
    |> Enum.map(&field_mapping/1)
  end

  defp field_mapping(%{"name" => name, "type" => "enriched_text"}) do
    {name, mapping_type("enriched_text")}
  end

  defp field_mapping(%{"name" => name, "values" => values}) do
    {name, mapping_type(values)}
  end

  defp field_mapping(%{"name" => name}) do
    {name, mapping_type("string")}
  end

  defp mapping_type(values) when is_map(values) do
    %{type: "text", fields: %{raw: %{type: "keyword"}}}
  end

  defp mapping_type(_default), do: %{type: "text"}
end
