defmodule TruedatWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use TruedatWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(TruedatWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(TruedatWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :not_found, type}) do
    conn
    |> put_status(:not_found)
    |> json(%{message: type})
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(TruedatWeb.ErrorView)
    |> render(:"403")
  end
end
