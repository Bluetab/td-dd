defmodule TdDdWeb.SystemController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdDd.Systems
  alias TdDd.Systems.System
  alias TdDd.Systems.SystemSearch
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.system_swagger_definitions()
  end

  swagger_path :index do
    description("List of Systems")
    response(200, "OK", Schema.ref(:SystemsResponse))
  end

  def index(conn, params) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]
    params = deleted(params)
    systems = SystemSearch.search_systems(claims, permission, params)
    render(conn, "index.json", systems: systems)
  end

  swagger_path :create do
    description("Creates System")
    produces("application/json")

    parameters do
      system(:body, Schema.ref(:SystemCreate), "System create attrs")
    end

    response(201, "OK", Schema.ref(:SystemResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def create(conn, %{"system" => params}) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, create(System))},
         {:ok, true} <- check_image_df(params),
         {:ok, %{system: system}} <- Systems.create_system(params, claims) do
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
    response(403, "Forbidden")
    response(404, "Not Found")
  end

  def show(conn, %{"id" => id}) do
    with {:ok, system} <- Systems.get_system(id) do
      render(conn, "show.json", system: system)
    end
  end

  swagger_path :update do
    description("Update System")
    produces("application/json")

    parameters do
      id(:path, :integer, "System ID", required: true)
      system(:body, Schema.ref(:SystemUpdate), "System update attrs")
    end

    response(201, "OK", Schema.ref(:SystemResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{"id" => id, "system" => params}) do
    with claims <- conn.assigns[:current_resource],
         {:ok, system} <- Systems.get_system(id),
         {:can, true} <- {:can, can?(claims, update(system))},
         {:ok, true} <- check_image_df(params),
         {:ok, %{system: updated_system}} <- Systems.update_system(system, params, claims) do
      render(conn, "show.json", system: updated_system)
    end
  end

  swagger_path :delete do
    description("Delete System")
    produces("application/json")

    parameters do
      id(:path, :integer, "System ID", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def delete(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         {:ok, system} <- Systems.get_system(id),
         {:can, true} <- {:can, can?(claims, delete(system))},
         {:ok, %{system: _deleted_system}} <- Systems.delete_system(system, claims) do
      send_resp(conn, :no_content, "")
    end
  end

  defp deleted(%{"all" => "true"}), do: Map.new()

  defp deleted(%{"all" => true}), do: Map.new()

  defp deleted(_params) do
    Map.put(%{}, :without, ["deleted_at"])
  end

  defp check_image_df(%{"df_content" => df_content}) do
    if check_image_type(Map.get(df_content, "image")) &&
         check_image_type(Map.get(df_content, "logo")) do
      {:ok, true}
    else
      {:error, "Invalid File"}
    end
  end

  defp check_image_df(_), do: {:ok, true}

  defp check_image_type(nil), do: true

  defp check_image_type(image_base64) do
    {start, _length} = :binary.match(image_base64, ";base64,")
    type = :binary.part(image_base64, 0, start)
    Regex.match?(~r/(jpg|jpeg|png|gif)/, type)
  end
end
