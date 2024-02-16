defmodule TdDqWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use TdDqWeb, :controller

  alias TdDqWeb.ErrorView

  def call(conn, {:can, false}) do
    call(conn, {:error, :forbidden})
  end

  def call(conn, {:error, {_id, :forbidden}}) do
    call(conn, {:error, :forbidden})
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(ErrorView)
    |> render("403.json")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(TdDqWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :can, false, _}) do
    call(conn, {:can, false})
  end

  def call(conn, {:error, _, %Ecto.Changeset{} = changeset, _}) do
    call(conn, {:error, changeset})
  end

  def call(conn, nil) do
    conn
    |> put_status(:not_found)
    |> put_view(TdDqWeb.ErrorView)
    |> render("404.json")
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(TdDqWeb.ErrorView)
    |> render("404.json")
  end
end
