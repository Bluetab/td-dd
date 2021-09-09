defmodule TdDdWeb.GrantApproverController do
  @moduledoc false

  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdDd.Grants
  alias TdDd.Grants.GrantApprover
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.grant_swagger_definitions()
  end

  swagger_path :index do
    description("List of grant approvers")
    response(200, "OK", Schema.ref(:GrantApproversResponse))
  end

  def index(conn, _params) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, list(GrantApprover))},
         grant_approvers <- Grants.list_grant_approvers() do
      render(conn, "index.json", grant_approvers: grant_approvers)
    end
  end

  swagger_path :create do
    description("Creates a grant approver")
    produces("application/json")

    parameters do
      grant_approver(:body, Schema.ref(:GrantApproverCreate), "Grant approver create attrs")
    end

    response(201, "OK", Schema.ref(:GrantApproverResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"grant_approver" => grant_approver_params}) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, create(GrantApprover))},
         {:ok, grant_approver} <- Grants.create_grant_approver(grant_approver_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.grant_approver_path(conn, :show, grant_approver))
      |> render("show.json", grant_approver: grant_approver)
    end
  end

  swagger_path :show do
    description("Show a Grant Approver")
    produces("application/json")

    parameters do
      id(:path, :integer, "Grant Approver ID", required: true)
    end

    response(200, "OK", Schema.ref(:GrantApproverResponse))
    response(400, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         grant_approver <- Grants.get_grant_approver!(id),
         {:can, true} <- {:can, can?(claims, view(grant_approver))} do
      render(conn, "show.json", grant_approver: grant_approver)
    end
  end

  swagger_path :delete do
    description("Delete a Grant Approver")
    produces("application/json")

    parameters do
      id(:path, :integer, "Grant Approver ID", required: true)
    end

    response(204, "No Content")
    response(400, "Client Error")
  end

  def delete(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         grant_approver <- Grants.get_grant_approver!(id),
         {:can, true} <- {:can, can?(claims, delete(grant_approver))},
         {:ok, _} <- Grants.delete_grant_approver(grant_approver) do
      send_resp(conn, :no_content, "")
    end
  end
end
