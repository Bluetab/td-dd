defmodule DataDictionaryWeb.DataFieldController do
  use DataDictionaryWeb, :controller
  use PhoenixSwagger

  alias DataDictionary.Auth.Guardian.Plug, as: GuardianPlug
  alias DataDictionary.DataStructures
  alias DataDictionary.DataStructures.DataField
  alias DataDictionaryWeb.ErrorView
  alias DataDictionaryWeb.SwaggerDefinitions

  action_fallback DataDictionaryWeb.FallbackController

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
    render(conn, "index.json", data_fields: data_fields)
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
      conn
      |> put_status(:created)
      |> put_resp_header("location", data_field_path(conn, :show, data_field))
      |> render("show.json", data_field: data_field)
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
    render(conn, "show.json", data_field: data_field)
  end

  def update(conn, %{"id" => id, "data_field" => data_field_params}) do
    data_field = DataStructures.get_data_field!(id)

    update_params = data_field_params
    |> Map.put("last_change_by", get_current_user_id(conn))
    |> Map.put("last_change_at", DateTime.utc_now())

    with {:ok, %DataField{} = data_field} <- DataStructures.update_data_field(data_field, update_params) do
      render(conn, "show.json", data_field: data_field)
    else
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
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

end
