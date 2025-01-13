defmodule TdDqWeb.ImplementationSearchController do
  use TdDqWeb, :controller

  alias TdDq.Implementations
  alias TdDq.Implementations.Actions
  alias TdDq.Implementations.Search.Indexer
  alias TdDq.Rules.Search

  action_fallback(TdDqWeb.FallbackController)

  @default_page 0
  @default_size 20

  def create(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Implementations, :query, claims) do
      %{results: _implementations, total: total} = response = do_search(claims, params)

      response = search_assigns(response)

      conn
      |> Actions.put_actions(claims, params)
      |> put_view(TdDqWeb.SearchView)
      |> put_resp_header("x-total-count", "#{total}")
      |> render("search.json", response)
    end
  end

  def reindex(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Implementations, :reindex, claims) do
      Indexer.reindex(:all)
      send_resp(conn, :accepted, "")
    end
  end

  defp search_assigns(%{results: implementations, scroll_id: scroll_id}) do
    [implementations: implementations, scroll_id: scroll_id]
  end

  defp search_assigns(%{results: implementations, aggregations: aggregations}) do
    [implementations: implementations, filters: aggregations]
  end

  defp search_assigns(%{results: implementations}) do
    [implementations: implementations]
  end

  defp do_search(_claims, %{"scroll" => _, "scroll_id" => _} = params) do
    Search.scroll_implementations(params)
  end

  defp do_search(claims, params) do
    page = Map.get(params, "page", @default_page)
    size = Map.get(params, "size", @default_size)

    params
    |> Map.drop(["page", "size"])
    |> Search.search_implementations(claims, page, size)
  end
end
