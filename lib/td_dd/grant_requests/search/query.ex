defmodule TdDd.GrantRequests.Search.Query do
  @moduledoc """
  Support for building grant search queries.
  """

  alias Truedat.Search.Query

  def build_query(%{} = permissions, params, aggs) do
    permissions
    |> build_filters()
    |> Query.build_query(params, aggs)
  end

  def build_filters(%{"approve_grant_request" => :none}), do: %{match_none: %{}}

  def build_filters(%{"approve_grant_request" => :all}), do: %{match_all: %{}}

  def build_filters(%{"approve_grant_request" => domain_ids}) do
    %{bool: %{should: [domain_filter(domain_ids)]}}
  end

  defp domain_filter(domain_ids) do
    Query.term_or_terms("data_structure_version.domain_ids", domain_ids)
  end
end
