defmodule TdDdWeb.DataStructuresTagsController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures
  alias TdDd.DataStructures.{DataStructure, DataStructuresTags, DataStructureTag}
  alias TdDdWeb.SwaggerDefinitions

  action_fallback TdDdWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.data_structure_tag_definitions()
  end

  swagger_path :update do
    description("Updates Relation between a Data Structure and a Tag")
    produces("application/json")

    parameters do
      data_structure_id(:path, :integer, "Data Structure ID", required: true)
      id(:path, :integer, "Data Structure Tag ID", required: true)

      tag(
        :body,
        Schema.ref(:UpdateLinkDataStructureTag),
        "link update attrs"
      )
    end

    response(201, "OK", Schema.ref(:LinkDataStructureTagResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{
        "data_structure_id" => data_structure_id,
        "id" => tag_id,
        "tag" => tag_params
      }) do
    with claims <- conn.assigns[:current_resource],
         %DataStructure{} = structure <- DataStructures.get_data_structure!(data_structure_id),
         %DataStructureTag{} = tag <- DataStructures.get_data_structure_tag!(tag_id),
         {:can, true} <- {:can, can?(claims, link_data_structure_tag(structure))},
         {:ok, %DataStructuresTags{} = link} <-
           DataStructures.link_tag(structure, tag, tag_params) do
      render(conn, "show.json", link: link)
    end
  rescue
    _e in Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> put_view(ErrorView)
      |> render("404.json")
  end
end
