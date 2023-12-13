defmodule TdDdWeb.GrantRequestGroupController do
  use TdDdWeb, :controller

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Grants.Requests

  action_fallback TdDdWeb.FallbackController

  def index(conn, _params) do
    grant_request_groups =
      case conn.assigns[:current_resource] do
        %{role: "admin"} -> Requests.list_grant_request_groups()
        %{user_id: user_id} -> Requests.list_grant_request_groups_by_user_id(user_id)
      end

    render(conn, "index.json", grant_request_groups: grant_request_groups)
  end

  def create(conn, %{"grant_request_group" => params}) do
    with claims <- conn.assigns[:current_resource],
         params <- with_created_by_id(params, claims),
         {:ok, params} <- with_valid_requests(params),
         :ok <- can_create_on_structures(claims, params),
         :ok <- Bodyguard.permit(Requests, :create_grant_request_group, claims, params),
         {:ok, %{group: %{id: id}}} <-
           Requests.create_grant_request_group(params),
         %{} = group <- Requests.get_grant_request_group!(id) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.grant_request_group_path(conn, :show, group))
      |> render("show.json", grant_request_group: group)
    end
  end

  defp with_created_by_id(params, %{user_id: created_by_id}) do
    user_id = Map.get(params, "user_id", created_by_id)

    params
    |> Map.put("user_id", user_id)
    |> Map.put("created_by_id", created_by_id)
  end

  defp with_valid_requests(%{"requests" => [_ | _] = requests} = params)
       when is_list(requests) do
    requests
    |> Enum.reduce_while([], &validate_child_request/2)
    |> case do
      {:error, _, _} = error -> error
      requests -> {:ok, Map.put(params, "requests", requests)}
    end
  end

  defp with_valid_requests(_),
    do: {:error, :unprocessable_entity, "at least one request is required"}

  defp validate_child_request(%{"grant_id" => grant_id} = request, requests) do
    case Grants.get_grant(grant_id) do
      nil -> {:halt, {:error, :not_found, "Grant"}}
      grant -> {:cont, requests ++ [Map.put(request, "grant", grant)]}
    end
  end

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

  # Grant removal request
  defp can_create_on_structure(_claims, %{"grant" => _grant}) do
    # No permissions for the time being. Maybe :create_grant_request
    # could be reused (currently checked for grant creation)
    {:cont, :ok}
  end

  defp can_create_on_structure(claims, %{"data_structure" => data_structure}) do
    case Bodyguard.permit(DataStructures, :create_grant_request, claims, data_structure) do
      :ok -> {:cont, :ok}
      error -> {:halt, error}
    end
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]
    group = Requests.get_grant_request_group!(id)

    with :ok <- Bodyguard.permit(Requests, :view, claims, group) do
      render(conn, "show.json", grant_request_group: group)
    end
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]
    group = Requests.get_grant_request_group!(id)

    with :ok <- Bodyguard.permit(Requests, :delete, claims, group),
         {:ok, %GrantRequestGroup{}} <- Requests.delete_grant_request_group(group) do
      send_resp(conn, :no_content, "")
    end
  end
end
