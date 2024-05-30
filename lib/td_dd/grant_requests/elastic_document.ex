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

    def mappings(_) do
      %{mappings: %{properties: dsv_properties}, settings: _settings} =
        ElasticDocumentProtocol.mappings(%DataStructureVersion{})

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

      settings = Cluster.setting(:grant_requests)
      %{mappings: %{properties: properties}, settings: settings}
    end

    def aggregations(_) do
      %{
        "user" => %{terms: %{field: "user.user_name", size: Cluster.get_size_field("user")}},
        "current_status" => %{
          terms: %{field: "current_status", size: Cluster.get_size_field("current_status")}
        },
        "taxonomy" => %{terms: %{field: "domain_ids", size: Cluster.get_size_field("taxonomy")}},
        "type" => %{terms: %{field: "type", size: Cluster.get_size_field("type")}}
      }
      |> merge_dynamic_fields("gr", "metadata")
      |> merge_dynamic_fields("dd", "note")
    end
  end
end
