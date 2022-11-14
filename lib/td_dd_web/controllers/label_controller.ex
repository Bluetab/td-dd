defmodule TdDdWeb.LabelController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.DataStructures.DataStructureLinks
  alias TdDd.DataStructures.Label
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.data_structure_link_swagger_definitions()
  end

  swagger_path :index do
    description("Show all the structure link labels")

    response(200, "OK")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(DataStructureLinks, :query_labels, claims),
         labels <- DataStructureLinks.list_labels() do
      render(conn, "index.json", labels: labels)
    end
  end

  swagger_path :create do
    description("Create a new label to annotate a data structure link")
    produces("application/json")

    parameters do
      label(
        :body,
        Schema.ref(:Label),
        "Label"
      )
    end

    response(201, "Created")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def create(conn, %{"name" => _name} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(DataStructureLinks, :create_label, claims, %{}),
         {:ok, %Label{} = label} <- DataStructureLinks.create_label(params) do
      conn
      |> put_status(:created)
      |> render("show.json", label: label)
    end
  end

  swagger_path :delete do
    description("Delete a label by ID")

    parameters do
      id(:path, :integer, "Label ID", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def delete(conn, %{"id" => _id} = params) do
    claims = conn.assigns[:current_resource]

    with %Label{} = label <- DataStructureLinks.get_label_by(params),
         :ok <- Bodyguard.permit(DataStructureLinks, :delete_label, claims, Label),
         {:ok, %Label{}} <- DataStructureLinks.delete_label(label) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :delete_by_name do
    description("Delete a label by name")

    parameters do
      name(:query, :string, "Label name", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def delete_by_name(conn, %{"name" => _name} = params) do
    claims = conn.assigns[:current_resource]

    with %Label{} = label <- DataStructureLinks.get_label_by(params),
         :ok <- Bodyguard.permit(DataStructureLinks, :delete_label, claims, Label),
         {:ok, %Label{}} <- DataStructureLinks.delete_label(label) do
      send_resp(conn, :no_content, "")
    end
  end
end
