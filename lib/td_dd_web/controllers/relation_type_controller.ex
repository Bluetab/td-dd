defmodule TdDdWeb.RelationTypeController do
  use TdDdWeb, :controller

  alias TdDd.DataStructures.RelationType
  alias TdDd.DataStructures.RelationTypes

  action_fallback TdDdWeb.FallbackController

  def index(conn, _params) do
    relation_types = RelationTypes.list_relation_types()
    render(conn, "index.json", relation_types: relation_types)
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

  def show(conn, %{"id" => id}) do
    relation_type = RelationTypes.get_relation_type!(id)
    render(conn, "show.json", relation_type: relation_type)
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

  def delete(conn, %{"id" => id}) do
    relation_type = RelationTypes.get_relation_type!(id)

    with {:ok, %RelationType{}} <- RelationTypes.delete_relation_type(relation_type) do
      send_resp(conn, :no_content, "")
    end
  end
end
