defmodule TdDd.Grants.GrantStructure do
  @moduledoc """
  Structure used for grant indexing, instead of TdDd.Grants.Grant, to allow
  multiple data structure version children per grant (each document has one
  grant and one data structure version child).
  """
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantStructure

  defstruct [:grant, :data_structure_version]

  defimpl Elasticsearch.Document do
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
          data_structure_version: %DataStructureVersion{} = dsv
        }) do
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
        data_structure_version: Elasticsearch.Document.encode(dsv)
      }
    end

    defp user_full_name(%{full_name: full_name}) do
      full_name
    end

    defp user_full_name(_), do: ""
  end
end
