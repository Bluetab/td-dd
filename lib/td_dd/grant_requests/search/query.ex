defmodule TdDd.GrantRequests.Search.Query do
  @moduledoc """
  Support for building grant search queries.
  """

  alias TdCore.Search.Query

  def build_query(%{} = permissions, params, query_data) do
    opts = Keyword.new(query_data)

    permissions
    |> build_filters()
    |> Query.build_query(params, opts)
  end

  defp build_filters(%{
         "approve_grant_request" => %{"domain" => :none, "structure" => structure_ids}
       }) do
    case structure_ids do
      :none -> %{match_none: %{}}
      structure_ids -> %{bool: %{should: [structure_filter(structure_ids)]}}
    end
  end

  defp build_filters(%{"approve_grant_request" => %{"domain" => :all}}), do: %{match_all: %{}}

  defp build_filters(%{
         "approve_grant_request" => %{"domain" => domain_ids, "structure" => :none}
       }) do
    %{bool: %{should: [domain_filter(domain_ids)]}}
  end

  defp build_filters(%{
         "approve_grant_request" => %{"domain" => domain_ids, "structure" => structure_ids}
       }) do
    %{bool: %{should: [domain_filter(domain_ids), structure_filter(structure_ids)]}}
  end

  defp domain_filter(domain_ids) do
    Query.term_or_terms("domain_ids", domain_ids)
  end

  defp structure_filter(structure_ids) do
    Query.term_or_terms("data_structure_id", structure_ids)
  end
end
