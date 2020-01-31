defmodule TdDdWeb.GraphController do
  use TdDdWeb, :controller
  # use PhoenixSwagger

  alias TdDd.Lineage
  alias TdDd.Lineage.Graph
  alias TdDd.Lineage.Graphs

  action_fallback(TdDdWeb.FallbackController)

  def create(conn, %{} = params) do
    with %Graph{id: id} <- do_drawing(params) do
      data =
        params
        |> Map.take(["ids", "type"])
        |> Map.put(:id, id)

      json = %{data: data} |> Jason.encode!()

      conn
      |> put_resp_header("location", Routes.graph_path(TdDdWeb.Endpoint, :show, id))
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(201, json)
    end
  end

  def show(conn, %{"id" => id} = _params) do
    with %Graph{data: data} <- Graphs.get!(id) do
      json = %{data: Map.put(data, :id, id)} |> Jason.encode!()

      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(200, json)
    end
  end

  defp do_drawing(%{"type" => "lineage", "ids" => [_ | _] = ids} = params) do
    Lineage.lineage(ids, options(params))
  end

  defp do_drawing(%{"type" => "impact", "ids" => [_ | _] = ids} = params) do
    Lineage.impact(ids, options(params))
  end

  defp do_drawing(%{"type" => "sample"}), do: Lineage.sample()

  defp options(%{"excludes" => excludes}), do: [excludes: excludes]
  defp options(_params), do: []
end
