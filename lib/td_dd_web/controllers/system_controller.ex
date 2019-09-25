defmodule TdDdWeb.SystemController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias Jason, as: JSON
  alias TdDd.Audit.AuditSupport
  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug
  alias TdDd.Systems
  alias TdDd.Systems.System
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.system_swagger_definitions()
  end

  swagger_path :index do
    description("List of Systems")
    response(200, "OK", Schema.ref(:SystemsResponse))
  end

  def index(conn, _params) do
    systems = Systems.list_systems()
    render(conn, "index.json", systems: systems)
  end

  swagger_path :create do
    description("Creates System")
    produces("application/json")

    parameters do
      system(:body, Schema.ref(:SystemCreate), "System create attrs")
    end

    response(201, "OK", Schema.ref(:SystemResponse))
    response(403, "Unauthorized")
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

  def create(conn, %{"system" => system_params}) do
    with {:ok, %System{} = system} <- Systems.create_system(system_params) do
      AuditSupport.system_created(conn, system)

      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.system_path(conn, :show, system))
      |> render("show.json", system: system)
    end
  end

  swagger_path :show do
    description("System Comment")
    produces("application/json")

    parameters do
      id(:path, :integer, "System ID", required: true)
    end

    response(200, "OK", Schema.ref(:SystemResponse))
    response(403, "Unauthorized")
    response(404, "Not Found")
  end

  def show(conn, %{"id" => id}) do
    system = Systems.get_system!(id)
    render(conn, "show.json", system: system)
  end

  swagger_path :update do
    description("Update System")
    produces("application/json")

    parameters do
      id(:path, :integer, "System ID", required: true)
      system(:body, Schema.ref(:SystemUpdate), "System update attrs")
    end

    response(201, "OK", Schema.ref(:SystemResponse))
    response(403, "Unauthorized")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{"id" => id, "system" => system_params}) do
    old_system = Systems.get_system!(id)

    with {:ok, %System{} = system} <- Systems.update_system(old_system, system_params) do
      AuditSupport.system_updated(conn, old_system, system)
      render(conn, "show.json", system: system)
    end
  end

  swagger_path :delete do
    description("Delete System")
    produces("application/json")

    parameters do
      id(:path, :integer, "System ID", required: true)
    end

    response(204, "No Content")
    response(403, "Unauthorized")
    response(422, "Unprocessable Entity")
  end

  def delete(conn, %{"id" => id}) do
    system = Systems.get_system!(id)

    with {:ok, %System{}} <- Systems.delete_system(system) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :get_system_groups do
    description("List of Systems Groups")
    produces("application/json")

    parameters do
      external_id(:path, :integer, "External ID", required: true)
    end

    response(200, "OK", Schema.ref(:SystemsGroupsResponse))
    response(403, "Unauthorized")
    response(404, "Not Found")
  end

  def get_system_groups(conn, %{"system_id" => system_external_id}) do
    user = GuardianPlug.current_resource(conn)

    with true <- Map.get(user, :is_admin) do
      groups = Systems.get_system_groups(system_external_id)

      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(:ok, JSON.encode!(%{data: groups}))
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")
    end
  end

  swagger_path :delete_structure_versions do
    description("Delete Structures Version")
    produces("application/json")

    parameters do
      id(:path, :integer, "System ID", required: true)
      group_name :path, :string, "Group Name", required: true
    end

    response(204, "No Content")
    response(403, "Unauthorized")
    response(422, "Unprocessable Entity")
  end

  def delete_structure_versions(conn, %{"system_id" => system_external_id, "group_name" => group}) do
    user = GuardianPlug.current_resource(conn)

    with true <- Map.get(user, :is_admin),
      {:ok, _} <- Systems.delete_structure_versions(system_external_id, group) do
      send_resp(conn, :no_content, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")
    end
  end
end
