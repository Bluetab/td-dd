defmodule DataDictionaryWeb.DataStructureController do
  use DataDictionaryWeb, :controller
  use PhoenixSwagger

  alias DataDictionary.Auth.Guardian.Plug, as: GuardianPlug
  alias DataDictionary.DataStructures
  alias DataDictionary.DataStructures.DataStructure
  alias DataDictionaryWeb.ErrorView
  alias DataDictionaryWeb.SwaggerDefinitions

  action_fallback DataDictionaryWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.data_structure_swagger_definitions()
  end

  swagger_path :index do
    get "/data_structures"
    description "List Data Structures"
    response 200, "OK", Schema.ref(:DataStructuresResponse)
  end

  def index(conn, _params) do
    data_structures = DataStructures.list_data_structures()
    render(conn, "index.json", data_structures: data_structures)
  end

  swagger_path :create do
    post "/data_structures"
    description "Creates Data Structure"
    produces "application/json"
    parameters do
      data_structure :body, Schema.ref(:DataStructureCreate), "Data Structure create attrs"
    end
    response 201, "OK", Schema.ref(:DataStructureResponse)
    response 400, "Client Error"
  end

  def create(conn, %{"data_structure" => data_structure_params}) do
    creation_params = data_structure_params
    |> Map.put("last_change_by", get_current_user_id(conn))
    |> Map.put("last_change_at", DateTime.utc_now())

    with {:ok, %DataStructure{} = data_structure} <- DataStructures.create_data_structure(creation_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", data_structure_path(conn, :show, data_structure))
      |> render("show.json", data_structure: data_structure)
    else
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  swagger_path :show do
    get "/data_structures/{id}"
    description "Show Data Structure"
    produces "application/json"
    parameters do
      id :path, :integer, "Data Structure ID", required: true
    end
    response 200, "OK", Schema.ref(:DataStructureResponse)
    response 400, "Client Error"
  end

  def show(conn, %{"id" => id}) do
    data_structure = DataStructures.get_data_structure!(id)
    render(conn, "show.json", data_structure: data_structure)
  end

  def update(conn, %{"id" => id, "data_structure" => data_structure_params}) do
    data_structure = DataStructures.get_data_structure!(id)

    update_params = data_structure_params
    |> Map.put("last_change_by", get_current_user_id(conn))
    |> Map.put("last_change_at", DateTime.utc_now())

    with {:ok, %DataStructure{} = data_structure} <- DataStructures.update_data_structure(data_structure, update_params) do
      render(conn, "show.json", data_structure: data_structure)
    else
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  def delete(conn, %{"id" => id}) do
    data_structure = DataStructures.get_data_structure!(id)
    with {:ok, %DataStructure{}} <- DataStructures.delete_data_structure(data_structure) do
      send_resp(conn, :no_content, "")
    end
  end

  defp get_current_user_id(conn) do
    GuardianPlug.current_resource(conn).id
  end

end
