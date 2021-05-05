defmodule TdCxWeb.ConfigurationSignerController do
  use TdCxWeb, :controller
  use PhoenixSwagger

  alias TdCx.Configurations
  alias TdCx.Configurations.Configuration
  alias TdCxWeb.ErrorView
  alias TdCxWeb.SwaggerDefinitions

  action_fallback(TdCxWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.configuration_definitions()
  end

  swagger_path :create do
    description("Creates a new configuration")
    produces("application/json")

    parameters do
      payload(
        :body,
        :object,
        "Payload used to sign a secret key in a configuration"
      )
    end

    response(201, "Created", Schema.ref(:SignResponse))
    response(401, "Unauthorized")
    response(422, "Client Error")
  end

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
