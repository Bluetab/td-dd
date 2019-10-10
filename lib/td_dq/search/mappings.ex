defmodule TdDq.Search.Mappings do
  @moduledoc """
  Elastic Search mappings for Quality Rule
  """
  alias TdCache.TemplateCache

  @raw_sort %{raw: %{type: "keyword"}, sort: %{type: "keyword", normalizer: "sortable"}}

  def get_mappings do
    content_mappings = %{properties: get_dynamic_mappings("dq")}

    mapping_type = %{
      id: %{type: "long"},
      business_concept_id: %{type: "text"},
      domain_ids: %{type: "long", null_value: -1},
      domain_parents: %{
        type: "nested",
        properties: %{
          id: %{type: "long"},
          name: %{type: "text", fields: %{raw: %{type: "keyword"}}}
        }
      },
      rule_type_id: %{type: "long"},
      version: %{type: "long"},
      name: %{type: "text", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      active: %{type: "boolean", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      description: %{type: "text", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      deleted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      updated_by: %{
        properties: %{
          id: %{type: "long"},
          user_name: %{type: "text", fields: %{raw: %{type: "keyword"}}},
          full_name: %{type: "text", fields: %{raw: %{type: "keyword"}}}
        }
      },
      current_business_concept_version: %{
        properties: %{
          id: %{type: "long"},
          name: %{type: "text", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
          content: %{
            properties: get_dynamic_mappings("bg", "user")
          }
        }
      },
      updated_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      goal: %{type: "long"},
      minimum: %{type: "long"},
      df_name: %{type: "text", fields: %{raw: %{type: "keyword"}}},
      rule_type: %{
        properties: %{
          id: %{type: "long"},
          name: %{fields: %{raw: %{type: "keyword", normalizer: "sortable"}}, type: "text"}
        }
      },
      type_params: %{
        properties: %{
          name: %{fields: %{raw: %{type: "keyword"}}, type: "text"}
        }
      },
      execution_result_info: %{
        properties: %{
          result_avg: %{type: "long"},
          last_execution_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
          result_text: %{type: "text", fields: %{raw: %{type: "keyword"}}}
        }
      },
      _confidential: %{type: "boolean"},
      df_content: content_mappings
    }

    settings = %{
      analysis: %{
        normalizer: %{
          sortable: %{type: "custom", char_filter: [], filter: ["lowercase", "asciifolding"]}
        }
      }
    }

    %{mappings: %{_doc: %{properties: mapping_type}}, settings: settings}
  end

  def get_dynamic_mappings(scope, type \\ nil) do
    scope
    |> TemplateCache.list_by_scope!()
    |> Enum.flat_map(&get_mappings(&1, scope, type))
    |> Enum.into(%{})
  end

  defp get_mappings(%{content: content}, "bg", type) do
    content
    |> Enum.filter(&(Map.get(&1, "type") == type))
    |> Enum.map(&field_mapping/1)
  end

  defp get_mappings(%{content: content}, _scope, _type) do
    Enum.map(content, &field_mapping/1)
  end

  defp field_mapping(%{"name" => name, "type" => "table"}) do
    {name, %{enabled: false}}
  end

  defp field_mapping(%{"name" => name, "type" => "url"}) do
    {name, %{enabled: false}}
  end

  defp field_mapping(%{"name" => name, "type" => "enriched_text"}) do
    {name, mapping_type("enriched_text")}
  end

  defp field_mapping(%{"name" => name, "type" => "user"}) do
    {name, %{type: "text", fields: @raw_sort}}
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
