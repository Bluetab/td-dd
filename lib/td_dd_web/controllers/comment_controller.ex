defmodule TdDdWeb.CommentController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.Comments
  alias TdDd.Comments.Comment
  alias TdDdWeb.SwaggerDefinitions

  action_fallback TdDdWeb.FallbackController

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
    with {:ok, %Comment{} = comment} <- Comments.create_comment(comment_params) do
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
    post "/comments"
    description "Update Comments"
    produces "application/json"
    parameters do
      comment :body, Schema.ref(:CommentCreate), "Comment update attrs"
    end
    response 201, "OK", Schema.ref(:CommentResponse)
    response 400, "Client Error"
  end
  def update(conn, %{"id" => id, "comment" => comment_params}) do
    comment = Comments.get_comment!(id)

    with {:ok, %Comment{} = comment} <- Comments.update_comment(comment, comment_params) do
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
      send_resp(conn, :no_content, "")
    end
  end
end
