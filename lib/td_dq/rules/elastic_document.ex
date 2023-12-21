defmodule TdDq.Rules.ElasticDocument do
  @moduledoc """
  Elasticsearch mapping and aggregation
  definition for Rules
  """

  alias Elasticsearch.Document
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
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
      bcv = Helpers.get_business_concept_version(rule)
      domain = Helpers.get_domain(rule)
      domain_ids = List.wrap(domain_id)

      df_content =
        rule
        |> Map.get(:df_content)
        |> Format.search_values(template, domain_id: domain_id)

      %{
        id: rule.id,
        business_concept_id: rule.business_concept_id,
        _confidential: confidential,
        domain: Map.take(domain, [:id, :external_id, :name]),
        domain_ids: domain_ids,
        current_business_concept_version: bcv,
        version: rule.version,
        name: rule.name,
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

    def aggregations(_) do
      %{
        "active.raw" => %{terms: %{field: "active.raw"}},
        "df_label.raw" => %{terms: %{field: "df_label.raw", size: 50}},
        "taxonomy" => %{terms: %{field: "domain_ids", size: 500}}
      }
      |> merge_dynamic_fields("dq", "df_content")
    end
  end
end
