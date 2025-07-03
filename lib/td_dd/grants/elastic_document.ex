defmodule TdDd.Grants.ElasticDocument do
  @moduledoc """
  Elasticsearch mapping and aggregation
  definition for Grant Structure

  Structure used for grant indexing, instead of TdDd.Grants.Grant, to allow
  multiple data structure version children per grant (each document has one
  grant and one data structure version child).
  """

  alias Elasticsearch.Document
  alias TdCore.Search.Cluster
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantStructure

  defimpl Document, for: GrantStructure do
    use ElasticDocument

    @impl Elasticsearch.Document
    def id(%GrantStructure{
          grant: %Grant{} = grant,
          data_structure_version: %DataStructureVersion{} = dsv
        }) do
      "#{grant.id}-#{grant.user_id}-#{dsv.id}"
    end

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%GrantStructure{
          grant: %Grant{} = grant,
          data_structure_version: dsv
        }) do
      dsv = if is_nil(dsv), do: nil, else: Elasticsearch.Document.encode(dsv)

      %{
        id: grant.id,
        detail: grant.detail,
        start_date: grant.start_date,
        end_date: grant.end_date,
        inserted_at: grant.inserted_at,
        updated_at: grant.updated_at,
        pending_removal: grant.pending_removal,
        user_id: grant.user_id,
        user: %{
          full_name: user_full_name(grant.user)
        },
        source_user_name: grant.source_user_name,
        data_structure_version: dsv
      }
    end

    defp user_full_name(%{full_name: full_name}) do
      full_name
    end

    defp user_full_name(_), do: ""
  end

  defimpl ElasticDocumentProtocol, for: GrantStructure do
    use ElasticDocument

    @search_fields ~w(user.full_name)

    def mappings(_) do
      %{mappings: %{properties: dsv_properties}, settings: _settings} =
        ElasticDocumentProtocol.mappings(%DataStructureVersion{})

      grants_config =
        :td_core
        |> Application.get_env(TdCore.Search.Cluster)
        |> Keyword.get(:indexes, [])
        |> Keyword.get(:grants, [])
        |> Map.new()

      dsv_properties =
        maybe_not_searcheable_field(dsv_properties, grants_config, :dsv_no_searcheable_fields)

      properties =
        %{
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
              user_name: %{type: "text", fields: Map.merge(@raw, @exact)},
              full_name: %{type: "text", fields: Map.merge(@raw, @exact)}
            }
          }
        }
        |> maybe_not_searcheable_field(grants_config, :grant_no_searcheable_fields)

      settings = :grants |> Cluster.setting() |> apply_lang_settings()
      %{mappings: %{properties: properties}, settings: settings}
    end

    def aggregations(_) do
      %{
        "taxonomy" => %{
          terms: %{
            field: "data_structure_version.domain_ids",
            size: Cluster.get_size_field("taxonomy")
          }
        },
        "type.raw" => %{
          terms: %{
            field: "data_structure_version.type.raw",
            size: Cluster.get_size_field("type.raw")
          }
        },
        "pending_removal.raw" => %{
          terms: %{
            field: "pending_removal.raw",
            size: Cluster.get_size_field("pending_removal.raw")
          }
        },
        "system_external_id" => %{
          terms: %{
            field: "data_structure_version.system.external_id.raw",
            size: Cluster.get_size_field("system_external_id")
          }
        }
      }
    end

    def query_data(_) do
      structure_query_data = ElasticDocumentProtocol.query_data(%DataStructureVersion{})

      structure_native_fields =
        structure_query_data
        |> Map.get(:native_fields, [])
        |> Enum.map(&"data_structure_version.#{&1}")

      structure_simple_search_fields =
        structure_query_data
        |> Map.get(:simple_search_fields, [])
        |> Enum.map(&"data_structure_version.#{&1}")

      %{
        aggs: aggregations(%GrantStructure{}),
        fields: @search_fields ++ structure_native_fields,
        simple_search_fields: @search_fields ++ structure_simple_search_fields
      }
    end

    defp maybe_not_searcheable_field(properties, config, config_key) do
      mapping_list =
        config
        |> Map.get(config_key, [])
        |> Enum.map(fn key -> String.to_atom(key) end)

      maybe_not_searcheable_field(properties, mapping_list)
    end

    defp maybe_not_searcheable_field(properties, []), do: properties

    defp maybe_not_searcheable_field(properties, mapping_list) do
      Enum.reduce(mapping_list, properties, fn key, acc ->
        Map.put(acc, key, %{enabled: false})
      end)
    end
  end
end
