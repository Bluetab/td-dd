defmodule TdDdWeb.GrantRequestController do
  use TdDdWeb, :controller
  import Canada, only: [can?: 2]

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup

  action_fallback TdDdWeb.FallbackController

  def index(conn, %{"grant_request_group_id" => id}) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, index(GrantRequest))},
         %{requests: requests} <- Grants.get_grant_request_group!(id) do
      render(conn, "index.json", grant_requests: requests)
    end
  end

  def index(conn, %{} = params) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, index(GrantRequest))},
         {:ok, grant_requests} <- Grants.list_grant_requests(params) do
      render(conn, "index.json", grant_requests: grant_requests)
    end
  end

  def create(conn, %{
        "grant_request_group_id" => grant_request_group_id,
        "grant_request" => grant_request_params
      }) do
    with claims <- conn.assigns[:current_resource],
         {:grant_request_group, %GrantRequestGroup{} = grant_request_group} <-
           {:grant_request_group, Grants.get_grant_request_group(grant_request_group_id)},
         data_structure_id <- Map.get(grant_request_params, "data_structure_id"),
         {:can, true} <- {:can, can?(claims, create(GrantRequest))},
         {:data_structure, %DataStructure{} = data_structure} <-
           {:data_structure, DataStructures.get_data_structure!(data_structure_id)},
         {:ok, %GrantRequest{} = grant_request} <-
           Grants.create_grant_request(grant_request_params, grant_request_group, data_structure) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.grant_request_path(conn, :show, grant_request))
      |> render("show.json", grant_request: grant_request)
    else
      {:grant_request_group, nil} -> {:error, :not_found, "GrantRequestGroup"}
      {:data_structure, nil} -> {:error, :not_found, "DataStructure"}
      error -> error
    end
  end

  def show(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, show(GrantRequest))} do
      grant_request = Grants.get_grant_request!(id)
      render(conn, "show.json", grant_request: grant_request)
    end
  end

  def update(conn, %{"id" => id, "grant_request" => grant_request_params}) do
    grant_request = Grants.get_grant_request!(id)

    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, update(GrantRequest))},
         {:ok, %GrantRequest{} = grant_request} <-
           Grants.update_grant_request(grant_request, grant_request_params) do
      render(conn, "show.json", grant_request: grant_request)
    end
  end

  def delete(conn, %{"id" => id}) do
    grant_request = Grants.get_grant_request!(id)

    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, delete(GrantRequest))},
         {:ok, %GrantRequest{}} <- Grants.delete_grant_request(grant_request) do
      send_resp(conn, :no_content, "")
    end
  end
end
