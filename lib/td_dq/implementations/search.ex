defmodule TdDq.Implementations.Search do
  @moduledoc """
  The Rule Implementations Search context
  """

  alias TdDq.Rules.Search, as: RulesSearch

  def search_by_rule_id(%{} = params, claims, rule_id, page \\ 0, size \\ 1_000) do
    params
    |> case do
      %{"filters" => filters} = params ->
        params
        |> Map.put("filters", Map.merge(%{"rule_id" => rule_id}, filters))

      %{} = params ->
        params
        |> Map.put("filters", %{
          "rule_id" => rule_id
        })
    end
    |> search(claims, page, size)
  end

  def search_executable(%{} = params, claims) do
    executable_filters =
      params
      |> Map.get("filters", %{})
      |> Map.put("executable", [true])

    params
    |> Map.put("filters", executable_filters)
    |> Map.delete("status")
    |> search(claims)
  end

  def search(%{} = params, claims, page \\ 0, size \\ 10_000) do
    %{results: implementations} =
      params
      |> filter_deleted()
      |> Map.drop(["page", "size"])
      |> RulesSearch.search_implementations(claims, page, size)

    implementations
  end

  defp filter_deleted(%{"status" => "deleted"} = params) do
    params
    |> Map.delete("status")
    |> Map.put("with", "deleted_at")
  end

  defp filter_deleted(%{} = params) do
    params
    |> Map.delete("status")
    |> Map.put("without", "deleted_at")
  end
end
