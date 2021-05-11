defmodule TdDdWeb.DataStructureTagController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureTag
  alias TdDdWeb.SwaggerDefinitions

  action_fallback TdDdWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.data_structure_tag_definitions()
  end

  swagger_path :index do
    description("List Data Structure Tags")
    produces("application/json")

    response(200, "OK", Schema.ref(:DataStructureTagsResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def index(conn, _params) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, index(DataStructureTag))},
         data_structure_tags <- DataStructures.list_data_structure_tags(preload: [:tagged_structures]) do
      render(conn, "index.json", data_structure_tags: data_structure_tags)
    end
  end

  swagger_path :create do
    description("Creates Data Structure Tag")
    produces("application/json")

    parameters do
      data_structure_tag(
        :body,
        Schema.ref(:CreateDataStructureTag),
        "DataStructureTag create attrs"
      )
    end

    response(201, "OK", Schema.ref(:DataStructureTagResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def create(conn, %{"data_structure_tag" => params}) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, create(DataStructureTag))},
         {:ok, %DataStructureTag{} = data_structure_tag} <-
           DataStructures.create_data_structure_tag(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.data_structure_tag_path(conn, :show, data_structure_tag)
      )
      |> render("show.json", data_structure_tag: data_structure_tag)
    end
  end

  swagger_path :show do
    description("Shows Data Structure Tag")
    produces("application/json")

    parameters do
      id(:path, :integer, "Data Structure Tag ID", required: true)
    end

    response(201, "OK", Schema.ref(:DataStructureTagResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def show(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, show(DataStructureTag))},
         data_structure_tag <- DataStructures.get_data_structure_tag!(id) do
      render(conn, "show.json", data_structure_tag: data_structure_tag)
    end
  end

  swagger_path :update do
    description("Updates Data Structure Tag")
    produces("application/json")

    parameters do
      data_structure_id(:path, :integer, "Data Structure ID")
      id(:path, :integer, "Data Structure Tag ID", required: true)

      data_structure_tag(
        :body,
        Schema.ref(:UpdateDataStructureTag),
        "DataStructureTag update attrs"
      )
    end

    response(201, "OK", Schema.ref(:DataStructureTagResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{"id" => id, "data_structure_tag" => params}) do
    data_structure_tag = DataStructures.get_data_structure_tag!(id)

    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, update(DataStructureTag))},
         {:ok, %DataStructureTag{} = data_structure_tag} <-
           DataStructures.update_data_structure_tag(data_structure_tag, params) do
      render(conn, "show.json", data_structure_tag: data_structure_tag)
    end
  end

  swagger_path :delete do
    description("Delete Data Structure Tag")
    produces("application/json")

    parameters do
      id(:path, :integer, "Data Structure Tag ID", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def delete(conn, %{"id" => id}) do
    data_structure_tag = DataStructures.get_data_structure_tag!(id)

    with claims <- conn.assigns[:current_resource],
         {:can, true} <- {:can, can?(claims, delete(DataStructureTag))},
         {:ok, %DataStructureTag{}} <-
           DataStructures.delete_data_structure_tag(data_structure_tag) do
      send_resp(conn, :no_content, "")
    end
  end
end
