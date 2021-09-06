defmodule TdDd.Search.Mappings do
  @moduledoc """
  Manages elasticsearch mappings
  """
  alias TdCache.TemplateCache
  alias TdDd.Search.Cluster
  alias TdDfLib.Format

  @raw %{raw: %{type: "keyword"}}
  @text %{text: %{type: "text"}}
  @raw_sort %{raw: %{type: "keyword"}, sort: %{type: "keyword", normalizer: "sortable"}}
  @raw_sort_ngram %{
    raw: %{type: "keyword"},
    sort: %{type: "keyword", normalizer: "sortable"},
    ngram: %{type: "text", analyzer: "ngram"}
  }

  def get_mappings do
    content_mappings = %{type: "object", properties: get_dynamic_mappings("dd")}

    properties = %{
      id: %{type: "long", index: false},
      name: %{type: "text", fields: @raw_sort_ngram},
      system: %{
        properties: %{
          id: %{type: "long", index: false},
          external_id: %{type: "text", fields: @raw},
          name: %{type: "text", fields: @raw_sort}
        }
      },
      domain: %{
        properties: %{
          id: %{type: "long"},
          name: %{type: "text", fields: @raw_sort},
          external_id: %{type: "text", fields: @raw}
        }
      },
      domain_parents: %{
        type: "nested",
        properties: %{
          id: %{type: "long"},
          name: %{type: "text", fields: @raw},
          external_id: %{type: "text", fields: @raw}
        }
      },
      parent: %{
        properties: %{
          name: %{type: "text", fields: @raw},
          external_id: %{type: "text", fields: @raw}
        }
      },
      group: %{type: "text", fields: @raw_sort},
      type: %{type: "text", fields: @raw_sort},
      field_type: %{type: "text", fields: @raw_sort},
      confidential: %{type: "boolean", fields: @raw},
      with_content: %{type: "boolean", fields: @raw},
      description: %{type: "text", fields: @raw},
      external_id: %{type: "keyword", index: false},
      domain_ids: %{type: "long"},
      deleted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      last_change_by: %{enabled: false},
      metadata: %{enabled: false},
      mutable_metadata: %{enabled: false},
      linked_concepts_count: %{type: "short"},
      inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      updated_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      path: %{type: "keyword", fields: @text},
      path_sort: %{type: "keyword", normalizer: "sortable"},
      data_fields: %{
        properties: %{
          name: %{type: "text"},
          id: %{type: "long", index: false}
        }
      },
      ancestry: %{enabled: false},
      latest_note: content_mappings,
      status: %{type: "keyword", null_value: ""},
      class: %{type: "text", fields: %{raw: %{type: "keyword", null_value: ""}}},
      classes: %{enabled: false},
      source_alias: %{type: "keyword", fields: @raw_sort},
      version: %{type: "short"},
      tags: %{type: "text", fields: %{raw: %{type: "keyword", null_value: ""}}},
      source: %{
        properties: %{
          id: %{type: "long"},
          type: %{type: "text", fields: @raw},
          external_id: %{type: "text", fields: @raw},
          config: %{type: "object", properties: get_dynamic_mappings("cx")}
        }
      },
      with_profiling: %{type: "boolean", fields: @raw}
    }

    settings = Cluster.setting(:structures)

    %{mappings: %{_doc: %{properties: properties}}, settings: settings}
  end

  def get_dynamic_mappings(scope) do
    scope
    |> TemplateCache.list_by_scope!()
    |> Enum.flat_map(&get_mappings/1)
    |> Enum.into(%{})
  end

  defp get_mappings(%{content: content}) do
    content
    |> Format.flatten_content_fields()
    |> Enum.map(&field_mapping/1)
  end

  defp field_mapping(%{"name" => name, "type" => "table"}) do
    {name, %{enabled: false}}
  end

  defp field_mapping(%{"name" => name, "type" => "url"}) do
    {name, %{enabled: false}}
  end

  defp field_mapping(%{"name" => name, "type" => "copy"}) do
    {name, %{enabled: false}}
  end

  defp field_mapping(%{"name" => name, "type" => type}) when type in ["domain", "system"] do
    {name,
     %{
       type: "nested",
       properties: %{
         id: %{type: "long"},
         name: %{type: "text", fields: @raw},
         external_id: %{type: "text", fields: @raw}
       }
     }}
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
    %{type: "text", fields: @raw}
  end

  defp mapping_type(_default), do: %{type: "text"}
end
