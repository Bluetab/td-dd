defmodule TdDdWeb.CommentController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.Comments
  alias TdDd.Comments.Comment
  alias TdDdWeb.SwaggerDefinitions
  alias TdDd.Audit
  alias Guardian.Plug, as: GuardianPlug

  action_fallback TdDdWeb.FallbackController

  @events %{update_comment: "update_comment",
            create_comment: "create_comment",
            delete_comment: "delete_comment"}

  def swagger_definitions do
    SwaggerDefinitions.comment_swagger_definitions()
  end

  swagger_path :index do
    get "/comments"
    description "List Comments"
    response 200, "OK", Schema.ref(:CommentsResponse)
  end
  def index(conn, _params) do
    comments = Comments.list_comments()
    render(conn, "index.json", comments: comments)
  end

  swagger_path :create do
    post "/comments"
    description "Creates Comments"
    produces "application/json"
    parameters do
      data_field :body, Schema.ref(:CommentCreate), "Comment create attrs"
    end
    response 201, "OK", Schema.ref(:CommentResponse)
    response 400, "Client Error"
  end
  def create(conn, %{"comment" => comment_params}) do
    current_user = GuardianPlug.current_resource(conn)
    creation_attrs = comment_params
      |> Map.put("user_id", current_user.id)
    with {:ok, %Comment{} = comment} <- Comments.create_comment(creation_attrs) do
      audit = %{"audit" => %{"resource_id" => comment.id, "resource_type" => "comment", "payload" => comment_params}}
      Audit.create_event(conn, audit, @events.create_comment)
      conn
      |> put_status(:created)
      |> put_resp_header("location", comment_path(conn, :show, comment))
      |> render("show.json", comment: comment)
    end
  end

  swagger_path :show do
    get "/comments/{id}"
    description "Show Comment"
    produces "application/json"
    parameters do
      id :path, :integer, "Comment ID", required: true
    end
    response 200, "OK", Schema.ref(:CommentResponse)
    response 400, "Client Error"
  end
  def show(conn, %{"id" => id}) do
    comment = Comments.get_comment!(id)
    render(conn, "show.json", comment: comment)
  end

  swagger_path :update do
    patch "/comments/{id}"
    description "Update Comments"
    produces "application/json"
    parameters do
      id :path, :integer, "Comment ID", required: true
      comment :body, Schema.ref(:CommentUpdate), "Comment update attrs"
    end
    response 201, "OK", Schema.ref(:CommentResponse)
    response 400, "Client Error"
  end
  def update(conn, %{"id" => id, "comment" => comment_params}) do
    comment = Comments.get_comment!(id)

    with {:ok, %Comment{} = comment} <- Comments.update_comment(comment, comment_params) do
      audit = %{"audit" => %{"resource_id" => id, "resource_type" => "comment", "payload" => comment_params}}
      Audit.create_event(conn, audit, @events.update_comment)
      render(conn, "show.json", comment: comment)
    end
  end

  swagger_path :delete do
    delete "/comments/{id}"
    description "Delete Comment"
    produces "application/json"
    parameters do
      id :path, :integer, "Comment ID", required: true
    end
    response 204, "No Content"
    response 400, "Client Error"
  end
  def delete(conn, %{"id" => id}) do
    comment = Comments.get_comment!(id)
    with {:ok, %Comment{}} <- Comments.delete_comment(comment) do
      audit = %{"audit" => %{"resource_id" => id, "resource_type" => "comment", "payload" => %{}}}
      Audit.create_event(conn, audit, @events.delete_comment)
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :get_comment_data_field do
    get "/data_fields/{data_field_id}/comment"
    description "Show Data Field Comment"
    produces "application/json"
    parameters do
      data_field_id :path, :integer, "Data Field ID", required: true
    end
    response 200, "OK", Schema.ref(:CommentResponse)
    response 400, "Client Error"
  end
  def get_comment_data_field(conn, %{"data_field_id" => resource_id}) do
    comment = Comments.get_comment_by_resource("Field", resource_id)
    comment = Map.replace!(comment, :user_id, GuardianPlug.current_resource(conn).user_name)
    render(conn, "show.json", comment: comment)
  end

  swagger_path :get_comment_data_structure do
    get "/data_structures/{data_structure_id}/comment"
    description "Show Data Structure Comment"
    produces "application/json"
    parameters do
      data_structure_id :path, :integer, "Data Structure ID", required: true
    end
    response 200, "OK", Schema.ref(:CommentResponse)
    response 400, "Client Error"
  end
  def get_comment_data_structure(conn, %{"data_structure_id" => resource_id}) do
    comment = Comments.get_comment_by_resource("Structure", resource_id)
    comment = Map.replace!(comment, :user_id, GuardianPlug.current_resource(conn).user_name)
    render(conn, "show.json", comment: comment)
  end
end
