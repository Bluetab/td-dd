defmodule TdDdWeb.DataStructureTypeController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureTypes
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.data_structure_type_definitions()
  end

  swagger_path :index do
    description("Get sources of the given type")
    produces("application/json")

    response(200, "OK", Schema.ref(:DataStructureTypesResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    if can?(claims, index(%DataStructureType{})) do
      data_structure_types =
        DataStructureTypes.list_data_structure_types()
        |> Enum.map(&DataStructureTypes.enrich_template/1)

      render(conn, "index.json", data_structure_types: data_structure_types)
    else
      conn
      |> put_status(:forbidden)
      |> put_view(ErrorView)
      |> render("403.json")
    end
  end

  swagger_path :create do
    description("Creates a new data structure type")
    produces("application/json")

    parameters do
      data_structure_type(
        :body,
        Schema.ref(:CreateDataStructureType),
        "Parameters used to create a data structure type"
      )
    end

    response(200, "OK", Schema.ref(:DataStructureTypeResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def create(conn, %{"data_structure_type" => data_structure_type_params}) do
    claims = conn.assigns[:current_resource]

    with true <- can?(claims, create(%DataStructureType{})),
         {:ok, %DataStructureType{} = data_structure_type} <-
           DataStructureTypes.create_data_structure_type(data_structure_type_params) do
      conn
      |> put_status(:created)
      |> render("show.json", data_structure_type: data_structure_type)
    end
  end

  swagger_path :show do
    description("Get data structure type with the given id")
    produces("application/json")

    parameters do
      id(:path, :string, "id of Data Structure Type", required: true)
    end

    response(200, "OK", Schema.ref(:DataStructureTypeResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with true <- can?(claims, show(%DataStructureType{})),
         data_structure_type <- DataStructureTypes.get_data_structure_type!(id) do
      render(conn, "show.json", data_structure_type: data_structure_type)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")
    end
  end

  swagger_path :update do
    description("Updates Data Structure Type")
    produces("application/json")

    parameters do
      id(:path, :string, "id of Data Structure Type", required: true)

      data_structure_type(
        :body,
        Schema.ref(:UpdateDataStructureType),
        "Parameters used to update a Data Structure type"
      )
    end

    response(200, "OK", Schema.ref(:DataStructureTypeResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def update(conn, %{"id" => id, "data_structure_type" => data_structure_type_params}) do
    claims = conn.assigns[:current_resource]

    with true <- can?(claims, update(%DataStructureType{})),
         data_structure_type <- DataStructureTypes.get_data_structure_type!(id),
         {:ok, %DataStructureType{} = data_structure_type} <-
           DataStructureTypes.update_data_structure_type(
             data_structure_type,
             data_structure_type_params
           ) do
      render(conn, "show.json", data_structure_type: data_structure_type)
    end
  end

  swagger_path :delete do
    description("Deletes a Data Structure Type")

    parameters do
      id(:path, :string, "Data Structure id", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with true <- can?(claims, delete(%DataStructureType{})),
         data_structure_type <- DataStructureTypes.get_data_structure_type!(id),
         {:ok, %DataStructureType{}} <-
           DataStructureTypes.delete_data_structure_type(data_structure_type) do
      send_resp(conn, :no_content, "")
    end
  end
end
