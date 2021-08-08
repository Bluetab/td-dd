defmodule TdDdWeb.GrantRequestGroupController do
  use TdDdWeb, :controller
  import Canada, only: [can?: 2]

  alias TdCache.UserCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants
  alias TdDd.Grants.GrantRequestGroup

  action_fallback TdDdWeb.FallbackController

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]
    do_index(conn, claims)
  end

  defp do_index(conn, %{role: "admin"}) do
    grant_request_groups = Grants.list_grant_request_groups()
    render(conn, "index.json", grant_request_groups: grant_request_groups)
  end

  defp do_index(conn, %{user_id: user_id}) do
    grant_request_groups = Grants.list_grant_request_groups_by_user_id(user_id)
    render(conn, "index.json", grant_request_groups: grant_request_groups)
  end

  def create(conn, %{"grant_request_group" => grant_request_group_params}) do
    params = with_default_request_date(grant_request_group_params)

    with claims <- conn.assigns[:current_resource],
         {:ok, params} <- with_user_id(params, claims),
         {:ok, params} <- with_valid_requests(params),
         {:ok, _} <- can_create_on_structures(claims, params),
         {:can, true} <- {:can, can?(claims, create_grant_request_group(params))},
         {:ok, %GrantRequestGroup{} = grant_request_group} <-
           Grants.create_grant_request_group(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.grant_request_group_path(conn, :show, grant_request_group)
      )
      |> render("show.json", grant_request_group: grant_request_group)
    end
  end

  defp with_default_request_date(%{"request_date" => request_date} = params)
       when not is_nil(request_date),
       do: params

  defp with_default_request_date(params),
    do: Map.put(params, "request_date", DateTime.utc_now())

  defp with_user_id(%{"user_id" => user_id} = params, _) do
    case UserCache.get(user_id) do
      {:ok, nil} ->
        {:error, :not_found, "User"}

      {:ok, user} ->
        {:ok, Map.put(params, "user_id", user.id)}
    end
  end

  defp with_user_id(%{"user_name" => user_name} = params, _) do
    case UserCache.get_by_user_name(user_name) do
      {:ok, nil} ->
        {:error, :not_found, "User"}

      {:ok, user} ->
        {:ok, Map.put(params, "user_id", user.id)}
    end
  end

  defp with_user_id(params, %{user_id: user_id}), do: {:ok, Map.put(params, "user_id", user_id)}

  defp with_valid_requests(%{"requests" => [_ | _] = requests, "type" => type} = params)
       when is_list(requests) do
    requests
    |> Enum.map(&Map.put(&1, "group_type", type))
    |> Enum.reduce_while([], &validate_child_request/2)
    |> case do
      {:error, _, _} = error -> error
      requests -> {:ok, Map.put(params, "requests", requests)}
    end
  end

  defp with_valid_requests(_),
    do: {:error, :unprocessable_entity, "at least one request is required"}

  defp validate_child_request(%{"data_structure_id" => data_structure_id} = request, requests) do
    case DataStructures.get_data_structure(data_structure_id) do
      nil -> {:halt, {:error, :not_found, "DataStructure"}}
      data_structure -> {:cont, requests ++ [Map.put(request, "data_structure", data_structure)]}
    end
  end

  defp validate_child_request(
         %{"data_structure_external_id" => data_structure_external_id} = request,
         requests
       ) do
    case DataStructures.get_data_structure_by_external_id(data_structure_external_id) do
      %DataStructure{} = data_structure ->
        request =
          request
          |> Map.put("data_structure", data_structure)
          |> Map.put("data_structure_id", data_structure.id)

        {:cont, requests ++ [request]}

      _ ->
        {:halt, {:error, :not_found, "DataStructure"}}
    end
  end

  defp validate_child_request(_request, _requests) do
    {:halt, {:error, :not_found, "DataStructure"}}
  end

  defp can_create_on_structures(claims, %{"requests" => requests}) do
    Enum.reduce_while(requests, nil, fn req, _ -> can_create_on_structure(claims, req) end)
  end

  defp can_create_on_structure(claims, %{"data_structure" => data_structure}) do
    if can?(claims, create_grant_request(data_structure)) do
      {:cont, {:ok, nil}}
    else
      {:halt, {:can, false}}
    end
  end

  def show(conn, %{"id" => id}) do
    grant_request_group = Grants.get_grant_request_group!(id)

    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, show(grant_request_group))} do
      render(conn, "show.json", grant_request_group: grant_request_group)
    end
  end

  def update(conn, %{"id" => id, "grant_request_group" => grant_request_group_params}) do
    grant_request_group = Grants.get_grant_request_group!(id)

    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, update(GrantRequestGroup))},
         {:ok, %GrantRequestGroup{} = grant_request_group} <-
           Grants.update_grant_request_group(grant_request_group, grant_request_group_params) do
      render(conn, "show.json", grant_request_group: grant_request_group)
    end
  end

  def delete(conn, %{"id" => id}) do
    grant_request_group = Grants.get_grant_request_group!(id)

    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, delete(GrantRequestGroup))},
         {:ok, %GrantRequestGroup{}} <- Grants.delete_grant_request_group(grant_request_group) do
      send_resp(conn, :no_content, "")
    end
  end
end
