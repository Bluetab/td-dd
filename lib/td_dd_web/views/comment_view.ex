defmodule TdDdWeb.CommentView do
  use TdDdWeb, :view
  alias TdDdWeb.CommentView

  def render("index.json", %{comments: comments}) do
    %{data: render_many(comments, CommentView, "comment.json")}
  end

  def render("show.json", %{comment: comment}) do
    %{data: render_one(comment, CommentView, "comment.json")}
  end

  def render("comment.json", %{comment: comment}) do
    %{id: comment.id,
      resource_id: comment.resource_id,
      resource_type: comment.resource_type,
      user_id: comment.user_id,
      content: comment.content}
  end
end
