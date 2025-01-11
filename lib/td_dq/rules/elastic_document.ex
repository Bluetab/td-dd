defmodule TdDq.Rules.ElasticDocument do
  @moduledoc """
  Elasticsearch mapping and aggregation
  definition for Rules
  """

  alias Elasticsearch.Document
  alias TdCore.Search.Cluster
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdDfLib.Content
  alias TdDq.Rules.Rule

  defimpl Document, for: Rule do
    use ElasticDocument

    alias TdCache.TemplateCache
    alias TdDfLib.Format
    alias TdDfLib.RichText
    alias TdDq.Search.Helpers

    @impl Elasticsearch.Document
    def id(%Rule{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%Rule{domain_id: domain_id} = rule) do
      template = TemplateCache.get_by_name!(rule.df_name) || %{content: []}
      updated_by = Helpers.get_user(rule.updated_by)
      confidential = Helpers.confidential?(rule)

      bcv =
        rule
        |> Helpers.get_business_concept_version()
        |> Content.legacy_content_support(:content, :dynamic_content)
        |> Map.delete(:dynamic_content)

      domain = Helpers.get_domain(rule)
      domain_ids = List.wrap(domain_id)

      df_content =
        rule
        |> Map.get(:df_content)
        |> Format.search_values(template, domain_id: domain_id)
        |> case do
          rule_content when is_map(rule_content) ->
            rule_content
            |> Enum.map(fn {key, %{"value" => value}} -> {key, value} end)
            |> Map.new()

          rule_content ->
            rule_content
        end

      %{
        id: rule.id,
        business_concept_id: rule.business_concept_id,
        _confidential: confidential,
        domain: Map.take(domain, [:id, :external_id, :name]),
        domain_ids: domain_ids,
        current_business_concept_version: bcv,
        version: rule.version,
        name: rule.name,
        ngram_name: rule.name,
        active: rule.active,
        description: RichText.to_plain_text(rule.description),
        deleted_at: rule.deleted_at,
        updated_by: updated_by,
        updated_at: rule.updated_at,
        inserted_at: rule.inserted_at,
        df_name: rule.df_name,
        df_label: Map.get(template, :label),
        df_content: df_content
      }
    end
  end

  defimpl ElasticDocumentProtocol, for: Rule do
    use ElasticDocument

    @boosted_fields ~w(ngram_name^3)
    @search_fields ~w(description)

    def mappings(_) do
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
          fields: %{raw: %{type: "keyword", normalizer: "sortable"}}
        },
        ngram_name: %{type: "search_as_you_type"},
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
              properties: get_dynamic_mappings("bg", type: "user")
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

      settings = :rules |> Cluster.setting() |> apply_lang_settings()

      %{mappings: %{properties: properties}, settings: settings}
    end

    def aggregations(_) do
      merged_aggregations("dq", "bg")
    end

    def query_data(_) do
      native_fields = @boosted_fields ++ @search_fields
      content_schema = Templates.content_schema_for_scope("dq")

      %{
        fields: native_fields ++ dynamic_search_fields(content_schema),
        aggs: merged_aggregations(content_schema, "bg")
      }
    end

    defp native_aggregations do
      %{
        "active.raw" => %{
          terms: %{field: "active.raw", size: Cluster.get_size_field("active.raw")}
        },
        "df_label.raw" => %{
          terms: %{field: "df_label.raw", size: Cluster.get_size_field("df_label.raw")}
        },
        "taxonomy" => %{terms: %{field: "domain_ids", size: Cluster.get_size_field("taxonomy")}}
      }
    end

    defp merged_aggregations(dq_content_or_scope, bg_content_or_scope) do
      native_aggregations = native_aggregations()

      native_aggregations
      |> merge_dynamic_aggregations(dq_content_or_scope)
      |> merge_dynamic_aggregations(
        bg_content_or_scope,
        "current_business_concept_version.content"
      )
    end
  end
end
