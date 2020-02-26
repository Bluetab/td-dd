defmodule TdDd.Systems.SystemSearch do
  @moduledoc """
  The Systems context.
  """
  import Ecto.Query, warn: false

  alias TdDd.Accounts.User
  alias TdDd.DataStructure.Search
  alias TdDd.Search.Aggregations
  alias TdDd.Systems

  def search_systems(%User{is_admin: true} = user, permission, params) do
    get_systems_with_count(user, permission, params)
  end

  def search_systems(%User{} = user, permission, params) do
    systems_with_count = get_systems_with_count(user, permission, params)
    Enum.filter(systems_with_count, fn system -> system.structures_count > 0 end)
  end

  defp get_systems_with_count(user, permission, params) do
    agg_results = Search.get_aggregations_values(user, permission, params, Aggregations.get_systems_agg_terms())
    systems = Systems.list_systems()
    Enum.map(systems, fn system ->
      structures_count =
        Enum.find(agg_results, %{"doc_count" => 0}, fn agg_result ->
          Map.get(agg_result, "key") == system.name
        end)
      %{
        id: system.id,
        name: system.name,
        external_id: system.external_id,
        df_content: system.df_content,
        structures_count: Map.get(structures_count, "doc_count")
      }
    end)
  end
end
