defmodule TdCxWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use TdCxWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(TdCxWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
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
    |> put_view(TdCxWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(TdCxWeb.ErrorView)
    |> render("403.json")
  end

  def call(conn, {:can, false}) do
    conn
    |> put_status(:forbidden)
    |> put_view(TdCxWeb.ErrorView)
    |> render("403.json")
  end

  def call(conn, {:vault_error, message}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      errors: [
        %{name: "vault_error", code: message}
      ]
    })
  end
end
