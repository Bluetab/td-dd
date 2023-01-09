defmodule TdDq.Search.Mappings do
  @moduledoc """
  Elastic Search mappings for Quality Rule
  """
  alias TdCache.TemplateCache
  alias TdDd.Search.Cluster
  alias TdDfLib.Format

  @raw %{raw: %{type: "keyword"}}
  @raw_sort %{raw: %{type: "keyword"}, sort: %{type: "keyword", normalizer: "sortable"}}

  def get_rule_mappings do
    content_mappings = %{properties: get_dynamic_mappings("dq")}

    properties = %{
      id: %{type: "long"},
      business_concept_id: %{type: "long"},
      domain: %{
        properties: %{
          id: %{type: "long"},
          name: %{type: "text", fields: @raw_sort},
          external_id: %{type: "text", fields: @raw}
        }
      },
      domain_ids: %{type: "long"},
      version: %{type: "long"},
      name: %{
        type: "text",
        boost: 2.0,
        fields: %{raw: %{type: "keyword", normalizer: "sortable"}}
      },
      active: %{type: "boolean", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      description: %{type: "text", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
      deleted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      updated_by: %{
        properties: %{
          id: %{type: "long"},
          user_name: %{type: "text", fields: @raw},
          full_name: %{type: "text", fields: @raw}
        }
      },
      current_business_concept_version: %{
        properties: %{
          id: %{type: "long"},
          name: %{type: "text", fields: @raw_sort},
          content: %{
            properties: get_dynamic_mappings("bg", "user")
          }
        }
      },
      updated_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      df_name: %{type: "text", fields: %{raw: %{type: "keyword"}}},
      df_label: %{type: "text", fields: %{raw: %{type: "keyword"}}},
      _confidential: %{type: "boolean"},
      df_content: content_mappings
    }

    settings = Cluster.setting(:rules)

    %{mappings: %{properties: properties}, settings: settings}
  end

  def get_implementation_mappings do
    content_mappings = %{properties: get_dynamic_mappings("ri")}

    properties = %{
      id: %{type: "long"},
      business_concept_id: %{type: "text"},
      rule_id: %{type: "long"},
      domain_ids: %{type: "long"},
      structure_ids: %{type: "long", null_value: -1},
      structure_aliases: %{type: "text", fields: @raw},
      structure_names: %{type: "text", fields: @raw},
      rule: %{
        properties: %{
          df_name: %{type: "text", fields: @raw},
          version: %{type: "long"},
          name: %{type: "text", boost: 1.5, fields: @raw_sort},
          active: %{type: "boolean", fields: %{raw: %{type: "keyword", normalizer: "sortable"}}},
          df_content: %{properties: get_dynamic_mappings("dq")}
        }
      },
      updated_by: %{
        properties: %{
          id: %{type: "long", index: false},
          user_name: %{type: "text", fields: @raw},
          full_name: %{type: "text", fields: @raw}
        }
      },
      current_business_concept_version: %{
        properties: %{
          id: %{type: "long", index: false},
          name: %{type: "text", fields: @raw_sort},
          content: %{
            properties: get_dynamic_mappings("bg", "user")
          }
        }
      },
      updated_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
      implementation_key: %{type: "text", boost: 2.0, fields: @raw},
      implementation_type: %{type: "text", fields: @raw_sort},
      execution_result_info: %{
        properties: %{
          result: %{type: "float"},
          errors: %{type: "long"},
          records: %{type: "long"},
          date: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
          result_text: %{
            type: "text",
            fields: %{raw: %{type: "keyword", null_value: "quality_result.no_execution"}}
          }
        }
      },
      _confidential: %{type: "boolean"},
      raw_content: %{
        properties: %{
          dataset: %{type: "text", fields: @raw},
          population: %{type: "text", fields: @raw},
          validations: %{type: "text", fields: @raw},
          system: %{properties: get_system_mappings()},
          source_id: %{type: "long"}
        }
      },
      dataset: %{
        type: "nested",
        properties: %{
          clauses: %{
            type: "nested",
            properties: %{
              left: %{properties: get_structure_mappings()},
              right: %{properties: get_structure_mappings()}
            }
          },
          join_type: %{type: "text", fields: @raw},
          structure: %{properties: get_structure_mappings()}
        }
      },
      population: get_condition_mappings(),
      populations: %{
        type: "nested",
        properties: %{
          conditions: get_condition_mappings()
        }
      },
      validations:
        get_condition_mappings([:operator, :structure, :value, :population, :modifier]),
      validation: %{
        type: "nested",
        properties: %{
          conditions:
            get_condition_mappings([:operator, :structure, :value, :population, :modifier])
        }
      },
      segments: %{properties: get_structure_mappings()},
      df_name: %{type: "text", fields: %{raw: %{type: "keyword"}}},
      df_content: content_mappings,
      executable: %{type: "boolean"},
      goal: %{type: "long"},
      minimum: %{type: "long"},
      result_type: %{type: "text", fields: %{raw: %{type: "keyword"}}},
      version: %{type: "short"},
      status: %{type: "keyword"}
    }

    settings = Cluster.setting(:implementations)

    %{mappings: %{properties: properties}, settings: settings}
  end

  def get_dynamic_mappings(scope, type \\ nil) do
    scope
    |> TemplateCache.list_by_scope!()
    |> Enum.flat_map(&get_mappings(&1, scope, type))
    |> Enum.into(%{})
  end

  defp get_mappings(%{content: content}, "bg", type) do
    content
    |> Format.flatten_content_fields()
    |> Enum.filter(&(Map.get(&1, "type") == type))
    |> Enum.map(&field_mapping/1)
  end

  defp get_mappings(%{content: content}, _scope, _type) do
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

  defp field_mapping(%{"name" => name, "type" => "enriched_text"}) do
    {name, mapping_type("enriched_text")}
  end

  defp field_mapping(%{"name" => name, "type" => "user"}) do
    {name, %{type: "text", fields: @raw_sort}}
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

  defp get_system_mappings do
    %{
      id: %{type: "long", index: false},
      external_id: %{type: "text", fields: @raw},
      name: %{type: "text", fields: @raw_sort}
    }
  end

  defp get_structure_mappings do
    %{
      alias: %{type: "text"},
      external_id: %{type: "text"},
      id: %{type: "long"},
      name: %{type: "text"},
      system: %{properties: get_system_mappings()},
      type: %{type: "text", fields: @raw},
      metadata: %{enabled: false}
    }
  end

  defp get_condition_mappings(opts \\ [:operator, :structure, :value, :modifier]) do
    properties =
      %{
        operator: %{
          properties: %{
            name: %{type: "text", fields: @raw},
            value_type: %{type: "text", fields: @raw},
            value_type_filter: %{type: "text", fields: @raw}
          }
        },
        structure: %{
          properties: get_structure_mappings()
        },
        value: %{
          type: "object",
          enabled: false
        },
        modifier: %{
          properties: %{
            name: %{type: "text", fields: @raw},
            params: %{type: "object", enabled: false}
          }
        },
        value_modifier: %{
          properties: %{
            name: %{type: "text", fields: @raw},
            params: %{type: "object"}
          }
        }
      }
      |> put_population(opts)
      |> Map.take(opts)

    %{
      type: "nested",
      properties: properties
    }
  end

  defp put_population(mappings, opts) do
    case :population in opts do
      true ->
        Map.put(mappings, :population, get_condition_mappings())

      _ ->
        mappings
    end
  end
end
