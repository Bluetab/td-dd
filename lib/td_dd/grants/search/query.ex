defmodule TdDd.Grants.Search.Query do
  @moduledoc """
  Support for building grant search queries.
  """

  alias Truedat.Search.Query

  def build_filters(%{"manage_grants" => manage_scope, "view_grants" => view_scope}, user_id) do
    user_filter = %{term: %{"user_id" => user_id}}

    case union(manage_scope, view_scope) do
      :none -> user_filter
      :all -> %{match_all: %{}}
      domain_ids -> %{bool: %{should: [domain_filter(domain_ids), user_filter]}}
    end
  end

  def build_filters(%{} = permissions, user_id) do
    permissions
    |> Map.put_new("manage_grants", :none)
    |> Map.put_new("view_grants", :none)
    |> Map.take(["manage_grants", "view_grants"])
    |> build_filters(user_id)
  end

  def build_query(filters, params, aggs) do
    Query.build_query(filters, params, aggs)
  end

  def union(:none, scope), do: scope
  def union(scope, :none), do: scope
  def union(:all, _), do: :all
  def union(_, :all), do: :all
  def union(ids, other_ids), do: Enum.uniq(ids ++ other_ids)

  defp domain_filter(domain_ids) do
    Query.term_or_terms("domain_id", domain_ids)
  end
end
