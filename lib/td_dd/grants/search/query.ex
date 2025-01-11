defmodule TdDd.Grants.Search.Query do
  @moduledoc """
  Support for building grant search queries.
  """

  alias TdCore.Search.Query

  def build_query(%{} = permissions, user_id, params, query_data) do
    permissions
    |> build_filters(user_id)
    |> do_build_query(params, query_data)
  end

  defp build_filters(%{"manage_grants" => manage_scope, "view_grants" => view_scope}, user_id) do
    user_filter = %{term: %{"user_id" => user_id}}

    case union(manage_scope, view_scope) do
      :none -> user_filter
      :all -> %{match_all: %{}}
      domain_ids -> %{bool: %{should: [domain_filter(domain_ids), user_filter]}}
    end
  end

  defp build_filters(%{} = permissions, user_id) do
    permissions
    |> Map.put_new("manage_grants", :none)
    |> Map.put_new("view_grants", :none)
    |> Map.take(["manage_grants", "view_grants"])
    |> build_filters(user_id)
  end

  defp do_build_query(filters, params, query_data) do
    opts = Keyword.new(query_data)
    Query.build_query(filters, params, opts)
  end

  defp union(:none, scope), do: scope
  defp union(scope, :none), do: scope
  defp union(:all, _), do: :all
  defp union(_, :all), do: :all
  defp union(ids, other_ids), do: Enum.uniq(ids ++ other_ids)

  defp domain_filter(domain_ids) do
    Query.term_or_terms("data_structure_version.domain_ids", domain_ids)
  end
end
