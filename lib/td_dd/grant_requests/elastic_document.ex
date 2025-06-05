defmodule TdDd.GrantRequests.ElasticDocument do
  @moduledoc """
  Elasticsearch mapping and aggregation
  definition for Grant Requests
  """

  alias Elasticsearch.Document
  alias TdCore.Search.Cluster
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup

  defimpl Document, for: GrantRequest do
    use ElasticDocument

    @impl Elasticsearch.Document
    def id(%GrantRequest{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(
          %{
            data_structure_version: dsv,
            group: %GrantRequestGroup{} = group,
            grant_id: grant_id,
            grant: grant,
            request_type: request_type
          } = grant_request
        ) do
      template =
        TemplateCache.get_by_name!(group.type) ||
          %{content: []}

      user = get_user(grant_request.user)
      created_by = get_user(grant_request.created_by)

      metadata =
        grant_request
        |> Map.get(:metadata)
        |> Format.search_values(template)
        |> case do
          metad when is_map(metad) ->
            Enum.into(metad, %{}, fn
              {key, %{"value" => value}} -> {key, value}
              {key, value} -> {key, value}
            end)

          metad ->
            metad
        end

      %{
        id: grant_request.id,
        current_status: grant_request.current_status,
        approved_by: grant_request.approved_by,
        domain_ids: grant_request.domain_ids,
        group_id: group.id,
        user_id: group.user_id,
        user: %{
          id: Map.get(user, :id),
          user_name: Map.get(user, :user_name, ""),
          email: Map.get(user, :email, ""),
          full_name: user_full_name(user)
        },
        created_by_id: group.created_by_id,
        created_by: %{
          id: Map.get(created_by, :id),
          email: Map.get(created_by, :email, ""),
          user_name: Map.get(created_by, :user_name, ""),
          full_name: user_full_name(created_by)
        },
        data_structure_id: grant_request.data_structure_id || grant.data_structure_id,
        data_structure_version: encode_data_structure_version(dsv),
        grant_id: grant_id,
        grant: encode_grant(grant),
        inserted_at: grant_request.inserted_at,
        type: group.type,
        metadata: metadata,
        modification_grant_id: group.modification_grant_id,
        request_type: request_type
      }
    end

    defp encode_grant(%Grant{id: id, data_structure_version: grant_dsv}) do
      %{
        id: id,
        data_structure_version: encode_data_structure_version(grant_dsv)
      }
    end

    defp encode_grant(%Ecto.Association.NotLoaded{}), do: nil

    defp encode_grant(nil), do: nil

    defp encode_data_structure_version(%DataStructureVersion{} = dsv) do
      Elasticsearch.Document.encode(dsv)
    end

    defp encode_data_structure_version(_), do: nil

    defp user_full_name(%{full_name: full_name}) do
      full_name
    end

    defp user_full_name(_), do: ""

    defp get_user(nil), do: %{}
    defp get_user(user), do: user
  end

  defimpl ElasticDocumentProtocol, for: GrantRequest do
    use ElasticDocument

    @search_fields ~w(user.full_name)

    def mappings(_) do
      config =
        :td_core
        |> Application.get_env(TdCore.Search.Cluster)
        |> Keyword.get(:indexes, [])
        |> Keyword.get(:grant_requests, [])
        |> Map.new()

      dsv_properties =
        %DataStructureVersion{}
        |> ElasticDocumentProtocol.mappings()
        |> dsv_properties(config)

      content_mappings = %{type: "object", properties: get_dynamic_mappings("gr")}

      properties = %{
        id: %{type: "long"},
        current_status: %{type: "keyword"},
        approved_by: %{type: "keyword"},
        domain_ids: %{type: "long"},
        group_id: %{type: "long"},
        user_id: %{type: "long"},
        user: %{
          type: "object",
          properties: %{
            id: %{type: "long", index: false},
            user_name: %{type: "keyword"},
            full_name: %{type: "text", fields: @raw}
          }
        },
        created_by_id: %{type: "long"},
        created_by: %{
          type: "object",
          properties: %{
            id: %{type: "long", index: false},
            user_name: %{type: "text", fields: @raw},
            full_name: %{type: "text", fields: @raw}
          }
        },
        data_structure_id: %{type: "long"},
        data_structure_version: %{type: "object", properties: dsv_properties},
        grant: %{
          type: "object",
          properties: %{
            id: %{type: "long", index: false},
            data_structure_version: %{type: "object", properties: dsv_properties}
          }
        },
        inserted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        type: %{type: "keyword"},
        metadata: content_mappings,
        modification_grant_id: %{type: "long"},
        request_type: %{type: "keyword"}
      }

      settings = :grant_requests |> Cluster.setting() |> apply_lang_settings()
      %{mappings: %{properties: properties}, settings: settings}
    end

    def aggregations(_) do
      merged_aggregations("gr", "dd")
    end

    def query_data(_) do
      structure_query_data = ElasticDocumentProtocol.query_data(%DataStructureVersion{})
      structure_native_fields = Map.get(structure_query_data, :native_fields, [])
      structure_simple_search_fields = Map.get(structure_query_data, :simple_search_fields, [])

      data_structure_version_fields =
        nested_search_fields(structure_native_fields, "data_structure_version")

      grant_structure_version_fields =
        nested_search_fields(structure_native_fields, "grant.data_structure_version")

      data_structure_simple_search_fields =
        nested_search_fields(structure_simple_search_fields, "data_structure_version")

      grant_structure_simple_search_fields =
        nested_search_fields(structure_simple_search_fields, "grant.data_structure_version")

      gr_content_schema = Templates.content_schema_for_scope("gr")
      dd_content_schema = Templates.content_schema_for_scope("dd")

      dynamic_fields =
        dynamic_search_fields(gr_content_schema, "metadata") ++
          dynamic_search_fields(dd_content_schema, "note")

      fields =
        @search_fields ++
          dynamic_fields ++ data_structure_version_fields ++ grant_structure_version_fields

      simple_search_fields =
        @search_fields ++
          data_structure_simple_search_fields ++ grant_structure_simple_search_fields

      %{
        aggs: merged_aggregations(gr_content_schema, dd_content_schema),
        fields: fields,
        simple_search_fields: simple_search_fields
      }
    end

    defp dsv_properties(%{mappings: %{properties: dsv_properties}}, index_config) do
      index_config
      |> Map.get(:dsv_disabled_fields, [])
      |> Enum.reduce(dsv_properties, fn field, properties ->
        Map.put(properties, field, %{enabled: false})
      end)
    end

    defp native_aggregations do
      %{
        "approved_by" => %{
          terms: %{field: "approved_by", size: Cluster.get_size_field("approved_by")}
        },
        "user" => %{terms: %{field: "user.user_name", size: Cluster.get_size_field("user")}},
        "current_status" => %{
          terms: %{field: "current_status", size: Cluster.get_size_field("current_status")}
        },
        "taxonomy" => %{terms: %{field: "domain_ids", size: Cluster.get_size_field("taxonomy")}},
        "type" => %{terms: %{field: "type", size: Cluster.get_size_field("type")}}
      }
    end

    defp merged_aggregations(gr_scope_or_content, dd_scope_or_content) do
      native_aggregations = native_aggregations()

      native_aggregations
      |> merge_dynamic_aggregations(gr_scope_or_content, "metadata")
      |> merge_dynamic_aggregations(dd_scope_or_content, "note")
    end

    defp nested_search_fields(fields, prefix) do
      Enum.map(fields, &"#{prefix}.#{&1}")
    end
  end
end
