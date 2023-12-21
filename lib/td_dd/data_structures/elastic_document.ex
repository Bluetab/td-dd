defmodule TdDd.DataStructures.ElasticDocument do
  @moduledoc """
  Elasticsearch mapping and aggregation
  definition for Data Structures
  """

  alias Elasticsearch.Document
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdDd.DataStructures.CatalogViewConfigs
  alias TdDd.DataStructures.DataStructureTypes
  alias TdDd.DataStructures.DataStructureVersion

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
      parent_id = List.last(Enum.map(path, &Integer.to_string(&1["data_structure_id"])), "")

      data_structure
      |> Map.take([
        :confidential,
        :domain_ids,
        :external_id,
        :id,
        :inserted_at,
        :linked_concepts,
        :source_id,
        :system_id
      ])
      |> Map.put(:note, content)
      |> Map.put(:domain, first_domain(data_structure))
      |> Map.put(:field_type, field_type(dsv))
      |> Map.put(:path_sort, path_sort(name_path))
      |> Map.put(:parent_id, parent_id)
      |> Map.put(:path, name_path)
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
          :updated_at,
          :version,
          :with_profiling
        ])
      )
      |> maybe_put_alias(alias_name)
    end

    defp maybe_put_alias(map, nil), do: map

    defp maybe_put_alias(%{name: original_name} = map, alias_name) do
      map
      |> Map.put(:name, alias_name)
      |> Map.put(:original_name, original_name)
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
  end

  defimpl ElasticDocumentProtocol, for: DataStructureVersion do
    use ElasticDocument

    @missing_term_name ElasticDocument.missing_term_name()

    def mappings(_) do
      content_mappings = %{properties: get_dynamic_mappings("dd")}

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

    def aggregations(_) do
      filters = filter_aggs()

      %{
        "system.name.raw" => %{terms: %{field: "system.name.raw", size: 500}},
        "group.raw" => %{terms: %{field: "group.raw", size: 50}},
        "type.raw" => %{terms: %{field: "type.raw", size: 50}},
        "confidential.raw" => %{terms: %{field: "confidential.raw"}},
        "class.raw" => %{terms: %{field: "class.raw"}},
        "field_type.raw" => %{terms: %{field: "field_type.raw", size: 50}},
        "with_content.raw" => %{terms: %{field: "with_content.raw"}},
        "tags.raw" => %{terms: %{field: "tags.raw", size: 50}},
        "linked_concepts" => %{terms: %{field: "linked_concepts"}},
        "taxonomy" => %{terms: %{field: "domain_ids", size: 500}},
        "with_profiling.raw" => %{terms: %{field: "with_profiling.raw"}}
      }
      |> merge_dynamic_fields("dd", "note")
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
                 missing: @missing_term_name
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
           %{terms: %{field: "_filters.#{filter}", missing: @missing_term_name}}}
        end)

      Map.merge(catalog_view_configs_filters, data_structure_types_filters)
    end
  end
end
