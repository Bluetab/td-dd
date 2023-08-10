defmodule TdDd.Search.Mappings do
  @moduledoc """
  Manages elasticsearch mappings
  """
  alias TdCache.TemplateCache
  alias TdDd.Search.Cluster
  alias TdDfLib.Format

  @raw %{raw: %{type: "keyword", null_value: ""}}
  @text %{text: %{type: "text"}}
  @raw_sort %{
    raw: %{type: "keyword", null_value: ""},
    sort: %{type: "keyword", normalizer: "sortable"}
  }
  @raw_sort_ngram %{
    raw: %{type: "keyword", null_value: ""},
    sort: %{type: "keyword", normalizer: "sortable"},
    ngram: %{type: "text", analyzer: "ngram"}
  }

  def get_mappings do
    content_mappings = %{type: "object", properties: get_dynamic_mappings("dd")}
    Application.get_all_env(:td_dd)

    properties = %{
      id: %{type: "long", index: false},
      data_structure_id: %{type: "long"},
      name: %{type: "text", fields: @raw_sort_ngram},
      original_name: %{type: "text", fields: @raw_sort_ngram},
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
      group: %{type: "text", fields: @raw_sort},
      type: %{type: "text", fields: @raw_sort},
      field_type: %{type: "text", fields: @raw_sort},
      confidential: %{type: "boolean", fields: @raw},
      with_content: %{type: "boolean", fields: @raw},
      description: %{type: "text", fields: @raw},
      external_id: %{type: "keyword", index: false},
      domain_ids: %{type: "long"},
      deleted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      metadata: %{
        enabled: false
      },
      linked_concepts: %{type: "boolean"},
      inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      updated_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      path: %{type: "keyword", fields: @text},
      path_sort: %{type: "keyword", normalizer: "sortable"},
      parent_id: %{type: "text", analyzer: "keyword"},
      note: content_mappings,
      class: %{type: "text", fields: %{raw: %{type: "keyword", null_value: ""}}},
      classes: %{enabled: true},
      source_alias: %{type: "keyword", fields: @raw_sort},
      version: %{type: "short"},
      tags: %{type: "text", fields: %{raw: %{type: "keyword", null_value: ""}}},
      with_profiling: %{type: "boolean", fields: @raw}
    }

    dynamic_templates = [
      %{metadata_filters: %{path_match: "_filters.*", mapping: %{type: "keyword"}}}
    ]

    settings = Cluster.setting(:structures)

    %{
      mappings: %{properties: properties, dynamic_templates: dynamic_templates},
      settings: settings
    }
  end

  def get_grant_mappings do
    %{mappings: %{properties: dsv_properties}, settings: _settings} = get_mappings()

    properties = %{
      data_structure_id: %{type: "long"},
      detail: %{type: "object"},
      user_id: %{type: "long"},
      pending_removal: %{type: "boolean", fields: @raw},
      start_date: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      end_date: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      updated_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      data_structure_version: %{type: "object", properties: dsv_properties},
      user: %{
        type: "object",
        properties: %{
          id: %{type: "long", index: false},
          user_name: %{type: "text", fields: @raw},
          full_name: %{type: "text", fields: @raw}
        }
      }
    }

    settings = Cluster.setting(:grants)
    %{mappings: %{properties: properties}, settings: settings}
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
    |> Enum.map(fn field ->
      field
      |> field_mapping
      |> maybe_boost(field)
    end)
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

  defp field_mapping(%{"name" => name, "widget" => "identifier"}) do
    {name, %{type: "keyword"}}
  end

  defp field_mapping(%{"name" => name, "type" => "domain"}) do
    {name, %{type: "long"}}
  end

  defp field_mapping(%{"name" => name, "type" => "system"}) do
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

  defp maybe_boost(field_tuple, %{"boost" => boost}) when boost in ["", "1"], do: field_tuple

  defp maybe_boost({name, field_value}, %{"boost" => boost}) do
    {boost_float, _} = Float.parse(boost)
    {name, Map.put(field_value, :boost, boost_float)}
  end

  defp maybe_boost(field_tuple, _), do: field_tuple

  defp mapping_type(_default), do: %{type: "text", fields: @raw}
end
