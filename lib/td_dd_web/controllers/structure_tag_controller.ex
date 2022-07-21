defmodule TdDdWeb.StructureTagController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures
  alias TdDd.DataStructures.Tags
  alias TdDdWeb.SwaggerDefinitions

  action_fallback TdDdWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.structure_tag_definitions()
  end

  swagger_path :index do
    description("Gets a data structure's tags")
    produces("application/json")

    parameters do
      data_structure_id(:path, :integer, "Data Structure ID", required: true)
    end

    response(200, "OK", Schema.ref(:StructureTagsResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def index(conn, %{"data_structure_id" => data_structure_id}) do
    with claims <- conn.assigns[:current_resource],
         %{} = structure <- DataStructures.get_data_structure!(data_structure_id),
         {:can, true} <- {:can, can?(claims, view_data_structure(structure))},
         links <- Tags.tags(structure) do
      render(conn, "index.json", links: links)
    end
  end

  swagger_path :update do
    description("Updates a data structure tag")
    produces("application/json")

    parameters do
      data_structure_id(:path, :integer, "Data Structure ID", required: true)
      id(:path, :integer, "Tag ID", required: true)

      tag(
        :body,
        Schema.ref(:UpdateStructureTag),
        "link update attrs"
      )
    end

    response(201, "OK", Schema.ref(:UpdateStructureTagResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{
        "data_structure_id" => data_structure_id,
        "id" => tag_id,
        "tag" => tag_params
      }) do
    with claims <- conn.assigns[:current_resource],
         %{} = structure <- DataStructures.get_data_structure!(data_structure_id),
         %{} = tag <- Tags.get_tag!(id: tag_id),
         {:can, true} <- {:can, can?(claims, tag(structure))},
         {:ok, %{structure_tag: %{} = link}} <-
           Tags.tag_structure(structure, tag, tag_params, claims) do
      render(conn, "show.json", link: link)
    end
  end

  swagger_path :delete do
    description("Delete Link between data structure and tag")
    produces("application/json")

    parameters do
      data_structure_id(:path, :integer, "Data Structure ID", required: true)
      id(:path, :integer, "Data Structure Tag ID", required: true)
    end

    response(202, "Accepted")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def delete(conn, %{"data_structure_id" => data_structure_id, "id" => tag_id}) do
    with claims <- conn.assigns[:current_resource],
         %{} = structure <- DataStructures.get_data_structure!(data_structure_id),
         %{} = tag <- Tags.get_tag!(id: tag_id),
         {:can, true} <- {:can, can?(claims, untag(structure))},
         {:ok, %{structure_tag: %{id: id}}} <-
           Tags.untag_structure(structure, tag, claims) do
      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(:accepted, Jason.encode!(%{data: %{id: id}}))
    end
  end
end
