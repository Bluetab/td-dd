defmodule TdDq.Implementations.ElasticDocument do
  @moduledoc """
  Elasticsearch mapping and aggregation
  definition for Implementations
  """

  alias Elasticsearch.Document
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdDq.Events.QualityEvents
  alias TdDq.Implementations
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleResults

  defimpl Document, for: Implementation do
    use ElasticDocument

    alias TdCache.TemplateCache
    alias TdDd.DataStructures.DataStructureVersion
    alias TdDfLib.Format
    alias TdDq.Search.Helpers

    @implementation_keys [
      :dataset,
      :deleted_at,
      :domain_id,
      :id,
      :implementation_key,
      :implementation_ref,
      :implementation_type,
      :populations,
      :rule_id,
      :inserted_at,
      :updated_at,
      :validation,
      :segments,
      :df_name,
      :executable,
      :goal,
      :minimum,
      :result_type,
      :status,
      :version
    ]
    @rule_keys [
      :active,
      :id,
      :name,
      :version,
      :df_name,
      :df_content
    ]

    @impl Elasticsearch.Document
    def id(%Implementation{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%Implementation{domain_id: domain_id} = implementation) do
      rule = Map.get(implementation, :rule)
      implementation = Implementations.enrich_implementation_structures(implementation, false)
      quality_event = QualityEvents.get_last_event_by_imp(implementation)

      result = RuleResults.get_latest_rule_result(implementation)

      execution_result_info =
        Implementation.get_execution_result_info(implementation, result, quality_event)

      domain_ids = List.wrap(domain_id)

      domain = Helpers.get_domain(domain_id)

      structures = Implementations.get_structures(implementation)
      structure_ids = get_structure_ids(structures)
      structure_names = get_structure_names(structures)
      structure_aliases = Implementations.get_sources(implementation)

      structure_links =
        implementation
        |> Map.get(:data_structures)
        |> Enum.map(fn
          %{
            type: link_type,
            current_version: dsv,
            data_structure: %{id: id, domain_ids: domain_ids, external_id: external_id}
          } ->
            %{
              link_type: link_type,
              structure:
                add_dsv_fields(
                  %{
                    domain_ids: domain_ids,
                    external_id: external_id,
                    id: id
                  },
                  dsv
                )
            }

          %{
            type: link_type
          } ->
            %{link_type: link_type}
        end)

      # linked_structures_ids is included in structure_links.structure.id
      # but using it would require nested query in the front-end
      linked_structures_ids =
        implementation
        |> Map.get(:data_structures)
        |> Enum.map(&Map.get(&1, :data_structure_id))

      # structure_domain_ids is included in
      # structure_links.structure.domain_ids but using it would require
      # nested query in the front-end and metrics connector
      structure_domain_ids =
        implementation
        |> Map.get(:data_structures)
        |> Enum.filter(&(&1.type === :validation))
        |> Enum.flat_map(fn imp_structures ->
          imp_structures
          |> Map.get(:data_structure, %{})
          |> Map.get(:domain_ids, [])
        end)
        |> Enum.uniq()

      structure_domains = Helpers.get_domains(structure_domain_ids)

      %Implementation{inserted_at: ref_inserted_at} =
        Map.get(implementation, :implementation_ref_struct)

      template = TemplateCache.get_by_name!(implementation.df_name) || %{content: []}

      df_content =
        implementation
        |> Map.get(:df_content)
        |> Format.search_values(template)

      implementation
      |> Map.take(@implementation_keys)
      |> transform_dataset()
      |> transform_populations()
      |> transform_validation()
      |> transform_segments()
      |> maybe_rule(rule)
      |> then(fn mapped_implementation ->
        rule_concept = Map.get(mapped_implementation, :current_business_concept_version)

        linked_concepts =
          Implementations.get_implementation_links(implementation, "business_concept")

        concepts =
          List.flatten([List.wrap(rule_concept) | linked_concepts])
          |> Enum.map(&Map.get(&1, :name, ""))
          |> Enum.reject(&(&1 == ""))

        Map.put(mapped_implementation, :concepts, concepts)
      end)
      |> Map.put(:raw_content, get_raw_content(implementation))
      |> Map.put(:inserted_at, ref_inserted_at)
      |> Map.put(:structure_aliases, structure_aliases)
      |> Map.put(:execution_result_info, execution_result_info)
      |> Map.put(:domain_ids, domain_ids)
      |> Map.put(:domain, domain)
      |> Map.put(:structure_domain_ids, structure_domain_ids)
      |> Map.put(:structure_domains, structure_domains)
      |> Map.put(:structure_ids, structure_ids)
      |> Map.put(:structure_names, structure_names)
      |> Map.put(:linked_structures_ids, linked_structures_ids)
      |> Map.put(:structure_links, structure_links)
      |> Map.put(:df_content, df_content)
    end

    defp add_dsv_fields(structure_fields, %DataStructureVersion{
           name: name,
           type: type,
           path: path
         }) do
      Map.merge(
        structure_fields,
        %{name: name, type: type, path: path}
      )
    end

    # A DataStructure current_version can be nil if all structure versions have
    # been logically deleted
    defp add_dsv_fields(structure_fields, nil), do: structure_fields

    defp get_raw_content(implementation) do
      raw_content = Map.get(implementation, :raw_content) || %{}

      Map.take(raw_content, [
        :dataset,
        :population,
        :validations,
        :source_id,
        :database
      ])
    end

    defp transform_dataset(%{dataset: dataset = [_ | _]} = data) do
      Map.put(data, :dataset, Enum.map(dataset, &dataset_row/1))
    end

    defp transform_dataset(data), do: data

    defp transform_populations(%{populations: populations = [_ | _]} = data) do
      encoded_populations =
        Enum.map(populations, fn %{conditions: condition_rows} ->
          %{conditions: Enum.map(condition_rows, &condition_row/1)}
        end)

      data
      |> Map.put(:populations, encoded_populations)
      |> Map.put(
        :population,
        Map.get(List.first(encoded_populations, %{conditions: []}), :conditions)
      )
    end

    defp transform_populations(data) do
      Map.put(data, :population, [])
    end

    defp transform_validation(%{validation: validation = [_ | _]} = data) do
      encoded_validation =
        Enum.map(validation, fn %{conditions: condition_rows} ->
          %{conditions: Enum.map(condition_rows, &condition_row/1)}
        end)

      data
      |> Map.put(:validation, encoded_validation)
      |> Map.put(
        :validations,
        Map.get(List.first(encoded_validation, %{conditions: []}), :conditions)
      )
    end

    defp transform_validation(data) do
      Map.put(data, :validations, [])
    end

    defp transform_segments(%{segments: segments = [_ | _]} = data) do
      Map.put(data, :segments, Enum.map(segments, &segmentation_row/1))
    end

    defp transform_segments(data), do: data

    defp dataset_row(row) do
      Map.new()
      |> Map.put(:clauses, Enum.map(Map.get(row, :clauses, []), &get_clause/1))
      |> Map.put(:structure, get_structure_fields(Map.get(row, :structure, %{})))
      |> Map.put(:join_type, Map.get(row, :join_type))
      |> Map.put(:alias, get_alias_fields(Map.get(row, :alias)))
    end

    defp condition_row(row) do
      Map.new()
      |> Map.put(:operator, get_operator_fields(Map.get(row, :operator, %{})))
      |> Map.put(:structure, get_structure_fields(Map.get(row, :structure, %{})))
      |> Map.put(:value, Map.get(row, :value, []))
      |> Map.put(:modifier, Map.get(row, :modifier, []))
      |> Map.put(:value_modifier, Map.get(row, :value_modifier, []))
      |> with_populations(row)
    end

    defp segmentation_row(row) do
      Map.new()
      |> Map.put(:structure, get_structure_fields(Map.get(row, :structure, %{})))
    end

    defp get_clause(row) do
      left = Map.get(row, :left, %{})
      right = Map.get(row, :right, %{})

      Map.new()
      |> Map.put(:left, get_structure_fields(left))
      |> Map.put(:right, get_structure_fields(right))
    end

    defp get_structure_fields(structure) do
      Map.take(structure, [
        :alias,
        :external_id,
        :id,
        :name,
        :path,
        :system,
        :type,
        :metadata,
        :parent_index
      ])
    end

    defp get_alias_fields(nil), do: nil
    defp get_alias_fields(alias_value), do: Map.take(alias_value, [:index, :text])

    defp get_operator_fields(operator) do
      Map.take(operator, [:name, :value_type, :value_type_filter])
    end

    defp with_populations(data, %{populations: populations = [_ | _]}) do
      Map.put(data, :populations, Enum.map(populations, &condition_row/1))
    end

    defp with_populations(data, _condition), do: data

    defp maybe_rule(data, %Rule{} = rule) do
      template = TemplateCache.get_by_name!(rule.df_name) || %{content: []}

      df_content =
        rule
        |> Map.get(:df_content)
        |> Format.search_values(template)

      rule = Map.put(rule, :df_content, df_content)

      confidential = Helpers.confidential?(rule)
      bcv = Helpers.get_business_concept_version(rule)
      updated_by = Helpers.get_user(rule.updated_by)

      data
      |> Map.put(:rule, Map.take(rule, @rule_keys))
      |> Map.put(:current_business_concept_version, bcv)
      |> Map.put(:_confidential, confidential)
      |> Map.put(:updated_by, updated_by)
      |> Map.put(:business_concept_id, Map.get(rule, :business_concept_id))
    end

    defp maybe_rule(data, _) do
      data
      |> Map.put(:_confidential, false)
    end

    defp get_structure_ids(structures) do
      structures
      |> Enum.map(&Map.get(&1, :id))
      |> Enum.uniq()
    end

    defp get_structure_names(structures) do
      structures
      |> Enum.map(&Map.get(&1, :name))
      |> Enum.filter(& &1)
      |> Enum.uniq()
    end
  end

  defimpl ElasticDocumentProtocol, for: Implementation do
    use ElasticDocument

    def mappings(_) do
      content_mappings = %{properties: get_dynamic_mappings("ri")}

      properties = %{
        id: %{type: "long"},
        business_concept_id: %{type: "text"},
        rule_id: %{type: "long"},
        domain_ids: %{type: "long"},
        structure_ids: %{type: "long", null_value: -1},
        structure_aliases: %{type: "text", fields: @raw},
        structure_names: %{type: "text", fields: @raw},
        linked_structures_ids: %{type: "long", null_value: -1},
        structure_links: %{
          type: "nested",
          properties: %{
            link_type: %{type: "text"},
            structure: %{
              type: "nested",
              properties: get_linked_structure_mapping()
            }
          }
        },
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
        concepts: %{type: "text", fields: @raw_sort},
        updated_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        implementation_key: %{type: "text", boost: 2.0, fields: @raw},
        implementation_type: %{type: "text", fields: @raw_sort},
        execution_result_info: %{
          properties: %{
            result: %{type: "text", fields: @raw_sort},
            errors: %{type: "long"},
            records: %{type: "long"},
            minimum: %{type: "text"},
            goal: %{type: "text"},
            details: %{enabled: false},
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

    def aggregations(_) do
      %{
        "execution_result_info.result_text" => %{
          terms: %{field: "execution_result_info.result_text.raw", size: 50}
        },
        "rule" => %{terms: %{field: "rule.name.raw", size: 50}},
        "source_external_id" => %{terms: %{field: "structure_aliases.raw", size: 50}},
        "status" => %{terms: %{field: "status"}},
        "result_type.raw" => %{terms: %{field: "result_type.raw"}},
        "taxonomy" => %{terms: %{field: "domain_ids", size: 500}},
        "structure_taxonomy" => %{
          terms: %{field: "structure_domain_ids", size: 500},
          meta: %{type: "domain"}
        },
        "linked_structures_ids" => %{
          terms: %{field: "linked_structures_ids", size: 50},
          meta: %{type: "search", index: "structures"}
        }
      }
      |> merge_dynamic_fields("ri", "df_content")
      |> merge_dynamic_fields("dq", "rule.df_content")
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

    defp get_system_mappings do
      %{
        id: %{type: "long", index: false},
        external_id: %{type: "text", fields: @raw},
        name: %{type: "text", fields: @raw_sort}
      }
    end

    defp get_linked_structure_mapping do
      %{
        domain_ids: %{type: "long"},
        external_id: %{type: "text"},
        id: %{type: "long"},
        name: %{type: "text"},
        type: %{type: "text", fields: @raw},
        path: %{type: "text"}
      }
    end
  end
end
