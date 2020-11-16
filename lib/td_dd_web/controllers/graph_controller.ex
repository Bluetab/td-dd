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
        |> Map.take(["ids", "type", "levels"])
        |> Map.put(:id, id)

      json = %{data: data} |> Jason.encode!()

      conn
      |> put_resp_header("location", Routes.graph_path(TdDdWeb.Endpoint, :show, id))
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(:created, json)
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

  def csv(conn, %{"id" => id}) do
    with %Graph{data: data} <- Graphs.get!(id) do
      type =
        data
        |> Map.get("opts")
        |> Map.get("type")

      attrs =
        Map.new()
        |> Map.put("type", type)
        |> Map.merge(Map.take(data, ["ids", "excludes"]))

      conn
      |> put_resp_content_type("text/csv", "utf-8")
      |> put_resp_header("content-disposition", "attachment; filename=\"graph_#{id}.zip\"")
      |> send_resp(:ok, do_csv(attrs))
    end
  end

  defp do_drawing(%{"type" => "lineage", "ids" => [_ | _] = ids} = params) do
    Lineage.lineage(ids, options(params))
  end

  defp do_drawing(%{"type" => "impact", "ids" => [_ | _] = ids} = params) do
    Lineage.impact(ids, options(params))
  end

  defp do_drawing(%{"type" => "sample"}), do: Lineage.sample()

  defp do_csv(%{"type" => "lineage", "ids" => [_ | _] = ids} = params) do
    Lineage.lineage_csv(ids, options(params))
  end

  defp do_csv(%{"type" => "impact", "ids" => [_ | _] = ids} = params) do
    Lineage.impact_csv(ids, options(params))
  end

  defp options(%{} = params) do
    []
    |> with_excludes(params)
    |> with_levels(params)
    |> with_header_labels(params)
  end

  defp with_excludes(acc, %{"excludes" => excludes}), do: acc ++ [excludes: excludes]
  defp with_excludes(acc, _params), do: acc

  defp with_levels(acc, %{"levels" => levels}), do: acc ++ [levels: levels]
  defp with_levels(acc, _params), do: acc

  defp with_header_labels(acc, %{"header_labels" => header_labels}),
    do: acc ++ [header_labels: header_labels]

  defp with_header_labels(acc, _params), do: acc
end
