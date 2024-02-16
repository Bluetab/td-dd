defmodule TdDdWeb.GroupController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.Groups
  alias TdDd.Systems
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.group_swagger_definitions()
  end

  swagger_path :index do
    description("List of Groups")
    produces("application/json")

    parameters do
      system_id(:path, :string, "System External ID", required: true)
    end

    response(200, "OK", Schema.ref(:GroupsResponse))
    response(403, "Forbidden")
    response(404, "Not Found")
  end

  def index(conn, %{"system_id" => system_external_id}) do
    claims = conn.assigns[:current_resource]

    with system when not is_nil(system) <- Systems.get_by(external_id: system_external_id),
         :ok <- Bodyguard.permit(Systems, :manage, claims, system) do
      groups = Groups.list_by_system(system_external_id)

      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(:ok, Jason.encode!(%{data: groups}))
    else
      {:error, error} -> {:error, error}
      nil -> {:error, :not_found}
    end
  end

  swagger_path :delete do
    description("Delete Group")
    produces("application/json")

    parameters do
      system_id(:path, :string, "System External Id", required: true)
      id(:path, :string, "Group Name", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def delete(conn, %{"system_id" => system_external_id, "id" => group}) do
    claims = conn.assigns[:current_resource]

    with system when not is_nil(system) <- Systems.get_by(external_id: system_external_id),
         :ok <- Bodyguard.permit(Systems, :manage, claims, system),
         :ok <- Groups.delete(system_external_id, group) do
      send_resp(conn, :no_content, "")
    else
      {:error, error} -> {:error, error}
      nil -> {:error, :not_found}
    end
  end
end
