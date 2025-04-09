defmodule TdDd.DataStructures.ElasticDocument do
  @moduledoc """
  Elasticsearch mapping and aggregation
  definition for Data Structures
  """

  alias Elasticsearch.Document
  alias TdCache.UserCache
  alias TdCore.Search.Cluster
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdDd.DataStructures.CatalogViewConfigs
  alias TdDd.DataStructures.DataStructureTypes
  alias TdDd.DataStructures.DataStructureVersion

  @id_path_agg %{
    terms: %{
      script: "params._source.id_path.join('-')",
      size: 65_535
    },
    aggs: %{
      filtered_children_ids: %{
        terms: %{field: "_id"}
      }
    }
  }

  def id_path_agg, do: %{"id_path" => @id_path_agg}

  defimpl Document, for: DataStructureVersion do
    @max_sortable_length 32_766

    @impl Elasticsearch.Document
    def id(%{data_structure_id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(
          %DataStructureVersion{
            data_structure:
              %{alias: alias_name, search_content: content, domain_ids: _domain_ids} =
                data_structure,
            path: path,
            tag_names: tags,
            metadata: metadata,
            mutable_metadata: mutable_metadata
          } = dsv
        ) do
      # IMPORTANT: Avoid enriching structs one-by-one in this function.
      # Instead, enrichment should be performed as efficiently as possible on
      # chunked data using `TdDd.DataStructures.enriched_structure_versions/1`.
      name_path = Enum.map(path, & &1["name"])
      id_path = Enum.map(path, &Map.get(&1, "data_structure_id", 0))
      parent_id = List.last(Enum.map(path, &Integer.to_string(&1["data_structure_id"])), "")

      last_change_at =
        case DateTime.compare(data_structure.updated_at, dsv.updated_at) do
          :gt -> data_structure.updated_at
          _ -> dsv.updated_at
        end

      data_structure
      |> Map.take([
        :confidential,
        :domain_ids,
        :external_id,
        :id,
        :updated_at,
        :inserted_at,
        :linked_concepts,
        :source_id,
        :system_id
      ])
      |> Map.put(:note, format_legacy_content(content))
      |> Map.put(:domain, first_domain(data_structure))
      |> Map.put(:field_type, field_type(dsv))
      |> Map.put(:path_sort, path_sort(name_path))
      |> Map.put(:parent_id, parent_id)
      |> Map.put(:path, name_path)
      |> Map.put(:id_path, id_path)
      |> Map.put(:source_alias, source_alias(dsv))
      |> Map.put(:system, system(data_structure))
      |> Map.put(:with_content, is_map(content) and map_size(content) > 0)
      |> Map.put(:tags, tags)
      |> Map.put(
        # Both mutable metadata (version metadata) and non mutable metadata (structure metadata)
        :metadata,
        Map.merge(
          metadata || %{},
          mutable_metadata || %{}
        )
        # clean empty field name
        |> Map.drop([""])
      )
      |> Map.merge(
        Map.take(dsv, [
          :_filters,
          :class,
          :classes,
          :data_structure_id,
          :deleted_at,
          :description,
          :group,
          :name,
          :type,
          :version,
          :with_profiling
        ])
      )
      |> Map.put(:last_change_at, last_change_at)
      |> maybe_put_alias(alias_name)
      |> maybe_add_non_published_note(data_structure)
      |> add_last_changed_note_fields(data_structure)
      |> add_ngram_fields()
    end

    defp maybe_put_alias(map, nil), do: map

    defp maybe_put_alias(%{name: original_name} = map, alias_name) do
      map
      |> Map.put(:name, alias_name)
      |> Map.put(:original_name, original_name)
    end

    defp add_ngram_fields(mapping) do
      mapping
      |> Map.put(:ngram_name, Map.get(mapping, :name))
      |> Map.put(:ngram_original_name, Map.get(mapping, :original_name))
      |> Map.put(:ngram_path, Map.get(mapping, :path))
    end

    defp path_sort(name_path) when is_list(name_path) do
      Enum.join(name_path, "~")
    end

    defp first_domain(%{domains: [domain | _]}),
      do: Map.take(domain, [:id, :external_id, :name])

    defp first_domain(_), do: nil

    defp system(%{system: %{} = system}), do: Map.take(system, [:id, :external_id, :name])

    defp field_type(%{metadata: %{"type" => type}})
         when byte_size(type) > @max_sortable_length do
      binary_part(type, 0, @max_sortable_length)
    end

    defp field_type(%{metadata: %{"type" => type}}), do: type
    defp field_type(_), do: nil

    defp source_alias(%{metadata: %{"alias" => value}}), do: value
    defp source_alias(_), do: nil

    defp maybe_add_non_published_note(map, %{
           draft_note: %{id: id, status: status, df_content: content}
         }) do
      Map.put(map, :non_published_note, %{
        id: id,
        status: status,
        note: format_legacy_content(content)
      })
    end

    defp maybe_add_non_published_note(map, %{
           pending_approval_note: %{id: id, status: status, df_content: content}
         }) do
      Map.put(map, :non_published_note, %{
        id: id,
        status: status,
        note: format_legacy_content(content)
      })
    end

    defp maybe_add_non_published_note(map, %{
           rejected_note: %{id: id, status: status, df_content: content}
         }) do
      Map.put(map, :non_published_note, %{
        id: id,
        status: status,
        note: format_legacy_content(content)
      })
    end

    defp maybe_add_non_published_note(map, _) do
      Map.put(map, :non_published_note, %{})
    end

    defp add_last_changed_note_fields(map, %{draft_note: note}) when not is_nil(note),
      do: maybe_add_last_changed_note_fields(map, note)

    defp add_last_changed_note_fields(map, %{pending_approval_note: note})
         when not is_nil(note),
         do: maybe_add_last_changed_note_fields(map, note)

    defp add_last_changed_note_fields(map, %{rejected_note: note}) when not is_nil(note),
      do: maybe_add_last_changed_note_fields(map, note)

    defp add_last_changed_note_fields(map, %{published_note: note}) when not is_nil(note),
      do: maybe_add_last_changed_note_fields(map, note)

    defp add_last_changed_note_fields(map, _ds),
      do: Map.merge(map, %{note_last_changed_by: nil, note_last_changed_at: nil})

    defp maybe_add_last_changed_note_fields(map, %{
           last_changed_by: nil,
           updated_at: last_changed_at
         }) do
      Map.merge(map, %{note_last_changed_at: last_changed_at, note_last_changed_by: nil})
    end

    defp maybe_add_last_changed_note_fields(map, %{
           last_changed_by: last_changed_by,
           updated_at: last_changed_at
         }) do
      case UserCache.get(last_changed_by) do
        {:ok, nil} ->
          Map.merge(map, %{note_last_changed_at: last_changed_at, note_last_changed_by: nil})

        {:ok, user} ->
          Map.merge(map, %{
            note_last_changed_by: %{
              id: user.id,
              user_name: user.user_name,
              full_name: user.full_name
            },
            note_last_changed_at: last_changed_at
          })
      end
    end

    defp maybe_add_last_changed_note_fields(map, _),
      do: Map.merge(map, %{note_last_changed_at: nil, note_last_changed_by: nil})

    defp format_legacy_content(content) when is_map(content) do
      Enum.into(content, %{}, fn
        {key, %{"value" => value}} ->
          {key, value}
      end)
    end

    defp format_legacy_content(content), do: content
  end

  defimpl ElasticDocumentProtocol, for: DataStructureVersion do
    use ElasticDocument

    @boosted_fields ~w(ngram_name*^3 ngram_original_name*^1.5 ngram_path*)
    @search_fields ~w(system.name description)
    @simple_search_fields ~w(name* original_name*)

    def mappings(_) do
      content_mappings = %{properties: get_dynamic_mappings("dd")}

      properties = %{
        id: %{type: "long", index: false},
        data_structure_id: %{type: "long"},
        name: %{type: "text", fields: @raw_sort},
        original_name: %{type: "text", fields: @raw_sort},
        ngram_name: %{type: "search_as_you_type"},
        ngram_original_name: %{type: "search_as_you_type"},
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
        metadata: %{enabled: false},
        linked_concepts: %{type: "boolean"},
        inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        updated_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        ngram_path: %{type: "search_as_you_type"},
        last_change_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        path: %{type: "keyword", fields: @text},
        path_sort: %{type: "keyword", normalizer: "sortable"},
        parent_id: %{
          type: "long",
          null_value: 0
        },
        note: content_mappings,
        note_last_changed_by: %{
          type: "object",
          properties: %{
            id: %{type: "long", index: false},
            user_name: %{type: "keyword", fields: @raw_sort},
            full_name: %{type: "text", fields: @raw}
          }
        },
        note_last_changed_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        class: %{type: "text", fields: %{raw: %{type: "keyword", null_value: ""}}},
        classes: %{enabled: true},
        source_alias: %{type: "keyword", fields: @raw_sort},
        version: %{type: "long"},
        tags: %{type: "text", fields: %{raw: %{type: "keyword", null_value: ""}}},
        with_profiling: %{type: "boolean", fields: @raw},
        non_published_note: %{
          properties: %{
            id: %{type: "long", index: false},
            status: %{type: "keyword", fields: @raw_sort},
            note: content_mappings
          }
        }
      }

      dynamic_templates = [
        %{metadata_filters: %{path_match: "_filters.*", mapping: %{type: "keyword"}}}
      ]

      settings =
        :structures
        |> Cluster.setting()
        |> maybe_apply_lang_settings()

      %{
        mappings: %{properties: properties, dynamic_templates: dynamic_templates},
        settings: settings
      }
    end

    def aggregations(_) do
      merged_aggregations("dd")
    end

    def query_data(_) do
      native_fields = @boosted_fields ++ @search_fields
      content_schema = Templates.content_schema_for_scope("dd")

      %{
        fields: native_fields ++ dynamic_search_fields(content_schema, "note"),
        aggs: merged_aggregations(content_schema),
        simple_search_fields: @simple_search_fields,
        native_fields: native_fields
      }
    end

    defp native_aggregations do
      %{
        "system.name.raw" => %{
          terms: %{field: "system.name.raw", size: Cluster.get_size_field("system.name.raw")}
        },
        "group.raw" => %{
          terms: %{field: "group.raw", size: Cluster.get_size_field("group.raw")}
        },
        "type.raw" => %{
          terms: %{field: "type.raw", size: Cluster.get_size_field("type.raw")}
        },
        "confidential.raw" => %{
          terms: %{field: "confidential.raw", size: Cluster.get_size_field("confidential.raw")}
        },
        "class.raw" => %{
          terms: %{field: "class.raw", size: Cluster.get_size_field("class.raw")}
        },
        "field_type.raw" => %{
          terms: %{field: "field_type.raw", size: Cluster.get_size_field("field_type.raw")}
        },
        "with_content.raw" => %{
          terms: %{field: "with_content.raw", size: Cluster.get_size_field("with_content.raw")}
        },
        "tags.raw" => %{
          terms: %{field: "tags.raw", size: Cluster.get_size_field("tags.raw")}
        },
        "linked_concepts" => %{
          terms: %{field: "linked_concepts", size: Cluster.get_size_field("linked_concepts")}
        },
        "taxonomy" => %{
          terms: %{field: "domain_ids", size: Cluster.get_size_field("taxonomy")}
        },
        "with_profiling.raw" => %{
          terms: %{
            field: "with_profiling.raw",
            size: Cluster.get_size_field("with_profiling.raw")
          }
        },
        "note_status" => %{
          terms: %{
            field: "non_published_note.status",
            size: Cluster.get_size_field("note_status")
          }
        },
        "note_last_changed_by" => %{
          terms: %{
            field: "note_last_changed_by.user_name",
            size: Cluster.get_size_field("note_last_changed_by.user_name")
          }
        }
      }
    end

    defp merged_aggregations(scope_or_content) do
      filters = filter_aggs()
      native_aggregations = native_aggregations()

      native_aggregations
      |> merge_dynamic_aggregations(scope_or_content, "note")
      |> Map.merge(filters)
    end

    defp filter_aggs do
      catalog_view_configs_filters =
        CatalogViewConfigs.list()
        |> Enum.filter(&(&1.field_type == "note"))
        |> Enum.map(fn
          %{field_type: "note", field_name: field_name} ->
            {"note.#{field_name}",
             %{
               terms: %{
                 field: "note.#{field_name}.raw",
                 size: Cluster.get_size_field("default_note")
               }
             }}
        end)
        |> Map.new()

      data_structure_types_filters =
        DataStructureTypes.metadata_filters()
        |> Map.values()
        |> List.flatten()
        |> Enum.uniq()
        |> Map.new(fn filter ->
          {"metadata.#{filter}",
           %{
             terms: %{
               field: "_filters.#{filter}",
               size: Cluster.get_size_field("default_metadata")
             }
           }}
        end)

      Map.merge(catalog_view_configs_filters, data_structure_types_filters)
    end

    defp maybe_apply_lang_settings(settings) do
      # TODO: connectors should be fixed instead to filter
      # by keyword fields
      if Cluster.setting(:structures, :apply_lang_settings) do
        apply_lang_settings(settings)
      else
        settings
      end
    end
  end
end
