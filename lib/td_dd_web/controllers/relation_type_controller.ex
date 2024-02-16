defmodule TdDdWeb.RelationTypeController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.DataStructures.RelationType
  alias TdDd.DataStructures.RelationTypes
  alias TdDdWeb.SwaggerDefinitions

  action_fallback TdDdWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.relation_type_definitions()
  end

  swagger_path :index do
    description("Get a list of relation type")
    produces("application/json")
    response(200, "OK", Schema.ref(:RelationTypesResponse))
    response(400, "Client Error")
  end

  def index(conn, _params) do
    relation_types = RelationTypes.list_relation_types()
    render(conn, "index.json", relation_types: relation_types)
  end

  swagger_path :create do
    description("Creates a new relation type")
    produces("application/json")

    parameters do
      relation_type(
        :body,
        Schema.ref(:CreateRelationType),
        "Parameters used to create a relation type"
      )
    end

    response(200, "OK", Schema.ref(:RelationTypeResponse))
    response(422, "Client Error")
    response(403, "Unauthorized")
  end

  def create(conn, %{"relation_type" => relation_type_params}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(RelationTypes, :create, claims),
         {:ok, %RelationType{} = relation_type} <-
           RelationTypes.create_relation_type(relation_type_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.relation_type_path(conn, :show, relation_type))
      |> render("show.json", relation_type: relation_type)
    end
  end

  swagger_path :show do
    description("Get Relation Type by id")
    produces("application/json")

    parameters do
      id(:path, :integer, "Relation Type ID", required: true)
    end

    response(200, "OK", Schema.ref(:RelationTypeResponse))
    response(422, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    relation_type = RelationTypes.get_relation_type!(id)
    render(conn, "show.json", relation_type: relation_type)
  end

  swagger_path :update do
    description("Updates the parameters of an existing relation type")
    produces("application/json")

    parameters do
      id(:path, :integer, "Relation Type ID", required: true)

      relation_type(
        :body,
        Schema.ref(:UpdateRelationType),
        "Parameters used to create a relation type"
      )
    end

    response(200, "OK", Schema.ref(:RelationTypeResponse))
    response(422, "Client Error")
  end

  def update(conn, %{"id" => id, "relation_type" => relation_type_params}) do
    claims = conn.assigns[:current_resource]
    relation_type = RelationTypes.get_relation_type!(id)

    with :ok <- Bodyguard.permit(RelationTypes, :manage, claims),
         {:ok, %RelationType{} = relation_type} <-
           RelationTypes.update_relation_type(relation_type, relation_type_params) do
      render(conn, "show.json", relation_type: relation_type)
    end
  end

  swagger_path :delete do
    description("Deletes a Relation Type given an id")

    parameters do
      id(:path, :integer, "Relation Type ID", required: true)
    end

    response(204, "No Content")
    response(422, "Client Error")
    response(403, "Unauthorized")
  end

  def delete(conn, %{"id" => id}) do
    relation_type = RelationTypes.get_relation_type!(id)

    with {:ok, %RelationType{}} <- RelationTypes.delete_relation_type(relation_type) do
      send_resp(conn, :no_content, "")
    end
  end
end
