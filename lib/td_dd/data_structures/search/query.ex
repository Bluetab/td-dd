defmodule TdDd.DataStructures.Search.Query do
  import Truedat.Search.Query, only: [term_or_terms: 2]

  @match_all %{match_all: %{}}
  @match_none %{match_none: %{}}

  def build_filters(%{"view_data_structure" => scope}), do: do_build_filters(scope)
  def build_filters(%{"link_data_structure" => scope}), do: do_build_filters(scope)
  def build_filters(%{}), do: @match_none

  def do_build_filters(:all), do: @match_all
  def do_build_filters(:none), do: @match_none
  def do_build_filters([_ | _] = domain_ids), do: term_or_terms("domain_id", domain_ids)

  def build_query(filters, params, aggs) do
    Truedat.Search.Query.build_query(filters, params, aggs)
  end
end
