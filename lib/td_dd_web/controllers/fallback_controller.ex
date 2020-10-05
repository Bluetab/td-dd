defmodule TdDdWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use TdDdWeb, :controller

  alias Jason, as: JSON

  require Logger

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(TdDdWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, _field, %Ecto.Changeset{} = changeset, _changes_so_far}) do
    call(conn, {:error, changeset})
  end

  def call(conn, {:error, :not_found}) do
    render_error(conn, :not_found)
  end

  def call(conn, {:error, error}) do
    conn
    |> put_resp_content_type("application/json", "utf-8")
    |> send_resp(:unprocessable_entity, JSON.encode!(%{error: error}))
  end

  def call(conn, {:can, false}) do
    render_error(conn, :forbidden)
  end

  def call(conn, {:cp, {:error, error}}) do
    Logger.warn("File copy operation failed with error #{inspect(error)}")
    render_error(conn, :insufficient_storage)
  end
end
