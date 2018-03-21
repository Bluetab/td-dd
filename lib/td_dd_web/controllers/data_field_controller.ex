defmodule TdDdWeb.DataFieldController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataField
  alias TdDdWeb.ErrorView
  alias TdDdWeb.SwaggerDefinitions

  action_fallback TdDdWeb.FallbackController

  @td_auth_api Application.get_env(:td_dd, :auth_service)[:api_service]

  def swagger_definitions do
    SwaggerDefinitions.data_field_swagger_definitions()
  end

  swagger_path :index do
    get "/data_fields"
    description "List Data Fields"
    response 200, "OK", Schema.ref(:DataFieldsResponse)
  end

  def index(conn, _params) do
    data_fields = DataStructures.list_data_fields()
    users = get_data_field_users(data_fields)
    render(conn, "index.json", data_fields: data_fields, users: users)
  end

  swagger_path :create do
    post "/data_fields"
    description "Creates Data Fields"
    produces "application/json"
    parameters do
      data_field :body, Schema.ref(:DataFieldCreate), "Data Field create attrs"
    end
    response 201, "OK", Schema.ref(:DataFieldResponse)
    response 400, "Client Error"
  end

  def create(conn, %{"data_field" => data_field_params}) do
    creation_params = data_field_params
    |> Map.put("last_change_by", get_current_user_id(conn))
    |> Map.put("last_change_at", DateTime.utc_now())

    with {:ok, %DataField{} = data_field} <- DataStructures.create_data_field(creation_params) do
      users = get_data_field_users(data_field)
      conn
      |> put_status(:created)
      |> put_resp_header("location", data_field_path(conn, :show, data_field))
      |> render("show.json", data_field: data_field, users: users)
    else
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :show do
    get "/data_fields/{id}"
    description "Show Data Field"
    produces "application/json"
    parameters do
      id :path, :integer, "Data Field ID", required: true
    end
    response 200, "OK", Schema.ref(:DataFieldResponse)
    response 400, "Client Error"
  end

  def show(conn, %{"id" => id}) do
    data_field = DataStructures.get_data_field!(id)
    users = get_data_field_users(data_field)
    render(conn, "show.json", data_field: data_field, users: users)
  end

  swagger_path :update do
    post "/data_fields"
    description "Update Data Fields"
    produces "application/json"
    parameters do
      data_field :body, Schema.ref(:DataFieldCreate), "Data Field update attrs"
    end
    response 201, "OK", Schema.ref(:DataFieldResponse)
    response 400, "Client Error"
  end

  def update(conn, %{"id" => id, "data_field" => data_field_params}) do
    data_field = DataStructures.get_data_field!(id)

    update_params = data_field_params
    |> Map.put("last_change_by", get_current_user_id(conn))
    |> Map.put("last_change_at", DateTime.utc_now())

    with {:ok, %DataField{} = data_field} <- DataStructures.update_data_field(data_field, update_params) do
      users = get_data_field_users(data_field)
      render(conn, "show.json", data_field: data_field, users: users)
    else
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :delete do
    delete "/data_fields/{id}"
    description "Delete Data Field"
    produces "application/json"
    parameters do
      id :path, :integer, "Data Field ID", required: true
    end
    response 204, "No Content"
    response 400, "Client Error"
  end

  def delete(conn, %{"id" => id}) do
    data_field = DataStructures.get_data_field!(id)
    with {:ok, %DataField{}} <- DataStructures.delete_data_field(data_field) do
      send_resp(conn, :no_content, "")
    end
  end

  defp get_current_user_id(conn) do
    GuardianPlug.current_resource(conn).id
  end

  defp get_data_field_users(%DataField{} = data_field), do: get_data_field_users([data_field])
  defp get_data_field_users(data_fields) when is_list(data_fields) do
    ids = Enum.reduce(data_fields, [], &([&1.last_change_by|&2]))
    @td_auth_api.search(%{"ids" => ids})
  end

end
