defmodule TdCxWeb.ConfigurationSignerController do
  use TdCxWeb, :controller

  alias TdCx.Configurations
  alias TdCx.Configurations.Configuration
  alias TdCxWeb.ErrorView

  action_fallback(TdCxWeb.FallbackController)

  def create(conn, %{"configuration_external_id" => external_id, "payload" => payload}) do
    with %Configuration{} = configuration <-
           Configurations.get_configuration_by_external_id!(external_id),
         {:ok, token} <- Configurations.sign(configuration, payload) do
      conn
      |> put_status(:created)
      |> render("show.json", token: token)
    else
      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> put_view(ErrorView)
        |> render("401.json")

      error ->
        error
    end
  rescue
    _e in Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> put_view(ErrorView)
      |> render("404.json")
  end
end
