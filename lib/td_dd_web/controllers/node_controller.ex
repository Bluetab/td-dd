defmodule TdDdWeb.NodeController do
  use TdDdWeb, :controller

  alias TdDd.Lineage.GraphData
  alias TdDd.Lineage.NodeQuery
  alias TdDd.Lineage.Units
  alias TdDd.Lineage.Units.Node

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, %{"domain_id" => domain_id} = _params) do
    opts = [domain_id: String.to_integer(domain_id)]
    query_nodes(conn, nil, opts)
  end

  def index(conn, _params) do
    query_nodes(conn)
  end

  def show(conn, %{"id" => id, "domain_id" => domain_id} = _params) do
    opts = [domain_id: String.to_integer(domain_id)]
    query_nodes(conn, id, opts)
  end

  def show(conn, %{"id" => id} = _params) do
    query_nodes(conn, id)
  end

  def update_nodes_domains(conn, _params) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(Units, :view_lineage, claims, %Node{}),
         {:ok, _data} <- NodeQuery.update_nodes_domains() do
      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(:no_content, "")
    end
  end

  defp query_nodes(conn, id \\ nil, opts \\ []) do
    claims = conn.assigns[:current_resource]

    case GraphData.nodes(id, opts, claims) do
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
