defmodule TdDdWeb.NodeController do
  use TdDdWeb, :controller

  # use PhoenixSwagger

  alias TdDd.Lineage.GraphData

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, _params) do
    query_nodes(conn)
  end

  def show(conn, %{"id" => id} = _params) do
    query_nodes(conn, id)
  end

  defp query_nodes(conn, id \\ nil) do
    case GraphData.nodes(id) do
      {:ok, data} ->
        json = %{data: data} |> Jason.encode!()

        conn
        |> put_resp_content_type("application/json", "utf-8")
        |> send_resp(200, json)

      {:error, :not_found} ->
        render_error(conn, :not_found)
    end
  end
end
