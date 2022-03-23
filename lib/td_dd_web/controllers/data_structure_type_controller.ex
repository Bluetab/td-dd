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
    description("Get data structure types")
    produces("application/json")

    response(200, "OK", Schema.ref(:DataStructureTypesResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, index(%DataStructureType{}))} do
      data_structure_types =
        DataStructureTypes.list_data_structure_types(preload: :metadata_fields)

      render(conn, "index.json", data_structure_types: data_structure_types)
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

    with data_structure_type <- DataStructureTypes.get!(id),
         {:can, true} <- {:can, can?(claims, show(data_structure_type))} do
      render(conn, "show.json", data_structure_type: data_structure_type)
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

  def update(conn, %{"id" => id, "data_structure_type" => params}) do
    claims = conn.assigns[:current_resource]
    data_structure_type = DataStructureTypes.get!(id)

    with {:can, true} <- {:can, can?(claims, update(data_structure_type))},
         {:ok, data_structure_type} <-
           DataStructureTypes.update_data_structure_type(data_structure_type, params) do
      render(conn, "show.json", data_structure_type: data_structure_type)
    end
  end
end
