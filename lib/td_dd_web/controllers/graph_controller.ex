defmodule TdDdWeb.GraphController do
  use TdDdWeb, :controller

  alias TdDd.Lineage
  alias TdDd.Lineage.Graph
  alias TdDd.Lineage.Graphs
  alias TdDd.Lineage.LineageEvent
  alias TdDd.Lineage.LineageEvents

  action_fallback(TdDdWeb.FallbackController)

  def create(conn, %{} = params) do
    with %{user_id: user_id} = _claims <- conn.assigns[:current_resource] do
      {code, response, _id} =
        do_drawing(user_id, params)
        |> response(:created)

      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(code, response |> Jason.encode!())
    end
  end

  defp response(
         {:already_calculated, %Graph{id: id, data: graph_data}},
         graph_done_response_code
       ) do
    data =
      graph_data
      |> Map.put(:id, id)

    {graph_done_response_code, data, id}
  end

  defp response(
         {:just_started, hash, task_reference},
         _graph_done_response_code
       ) do
    {
      :accepted,
      %{
        graph_hash: hash,
        status: "JUST_STARTED",
        task_reference: task_reference
      },
      hash
    }
  end

  defp response(
         {:already_started, %LineageEvent{graph_hash: hash} = event},
         _graph_done_response_code
       ) do
    {
      :accepted,
      TdDdWeb.LineageEventView.render("show.json", %{lineage_event: event}),
      hash
    }
  end

  def show(conn, %{"id" => id_str} = _params) do
    %{user_id: user_id} = conn.assigns[:current_resource]

    case Graphs.get(id_str) do
      %{params: create_params, is_stale: true} when not is_nil(create_params) ->
        {code, response, _id} =
          do_drawing(
            user_id,
            Map.put(create_params, "isRedirected", true)
          )
          |> response(:ok)

        conn
        |> put_resp_content_type("application/json", "utf-8")
        |> send_resp(code, response |> Jason.encode!())

      %{id: id, data: data} ->
        json = %{data: Map.put(data, :id, id)} |> Jason.encode!()

        conn
        |> put_resp_content_type("application/json", "utf-8")
        |> send_resp(200, json)

      error ->
        error
    end
  end

  def get_graph_by_hash(conn, %{"hash" => hash} = _params) do
    {code, data} =
      with %LineageEvent{status: "COMPLETED"} <- LineageEvents.last_event_by_hash(hash),
           %Graph{id: id, data: data} <- Graphs.find_by_hash!(hash) do
        {:ok, Map.put(data, :hash, hash) |> Map.put(:id, id)}
      else
        nil ->
          {:not_found, %{}}

        %LineageEvent{status: "ALREADY_STARTED"} = event ->
          {:accepted, TdDdWeb.LineageEventView.render("show.json", %{lineage_event: event})}

        %LineageEvent{status: "FAILED"} = event ->
          {:internal_server_error,
           TdDdWeb.LineageEventView.render("show.json", %{lineage_event: event})}

        %LineageEvent{status: "TIMED_OUT"} = event ->
          {:internal_server_error,
           TdDdWeb.LineageEventView.render("show.json", %{lineage_event: event})}
      end

    json = data |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json", "utf-8")
    |> send_resp(code, json)
  end

  def csv(conn, %{"id" => id}) do
    with %Graph{data: data} <- Graphs.get(id) do
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

  defp do_drawing(user_id, %{"type" => "lineage", "ids" => [_ | _] = ids} = params) do
    Lineage.lineage(ids, user_id, options(params))
  end

  defp do_drawing(user_id, %{"type" => "impact", "ids" => [_ | _] = ids} = params) do
    Lineage.impact(ids, user_id, options(params))
  end

  defp do_drawing(user_id, %{"type" => "sample"}) do
    Lineage.sample(user_id)
  end

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
