defmodule TdDq.Rules.Implementations.Search do
  @moduledoc """
  The Rule Implementations Search context
  """

  alias TdDq.Rules.Search, as: RulesSearch

  def search_by_rule_id(%{} = params, user, rule_id, page \\ 0, size \\ 1_000) do
    params
    |> Map.put("filters", %{"rule_id" => rule_id})
    |> search(user, page, size)
  end

  def search_executable(%{} = params, user) do
    params
    |> Map.delete("status")
    |> search(user)
  end

  def search(%{} = params, user, page \\ 0, size \\ 10_000) do
    %{results: implementations} =
      params
      |> filter_deleted()
      |> Map.drop(["page", "size"])
      |> RulesSearch.search(user, page, size, :implementations)

    implementations
  end

  defp filter_deleted(%{"status" => "deleted"} = params) do
    params
    |> Map.delete("status")
    |> Map.put(:with, ["deleted_at"])
  end

  defp filter_deleted(%{} = params) do
    params
    |> Map.delete("status")
    |> Map.put(:without, ["deleted_at"])
  end
end
