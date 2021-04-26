defmodule TdCxWeb.ConfigurationController do
  use TdCxWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdCx.Configurations
  alias TdCx.Configurations.Configuration
  alias TdCxWeb.ErrorView
  alias TdCxWeb.SwaggerDefinitions

  action_fallback(TdCxWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.configuration_definitions()
  end

  swagger_path :index do
    description("Get configurations")
    produces("application/json")

    parameters do
      type(:query, :string, "query string", required: false)
    end

    response(200, "OK", Schema.ref(:ConfigurationsResponse))
    response(422, "Client Error")
  end

  def index(conn, params) do
    configurations = Configurations.list_configurations(params, [:secrets])
    render(conn, "index.json", configurations: configurations)
  end

  swagger_path :create do
    description("Creates a new configuration")
    produces("application/json")

    parameters do
      configuration(
        :body,
        Schema.ref(:CreateConfiguration),
        "Parameters used to create a configuration"
      )
    end

    response(200, "OK", Schema.ref(:ConfigurationResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def create(conn, %{"configuration" => configuration_params}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, create(Configuration))},
         {:ok, %Configuration{} = configuration} <-
           Configurations.create_configuration(configuration_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.configuration_path(conn, :show, configuration))
      |> render("show.json", configuration: configuration)
    end
  end

  swagger_path :show do
    description("Get configuration with the given external_id")
    produces("application/json")

    parameters do
      external_id(:path, :string, "external id of configuration", required: true)
    end

    response(200, "OK", Schema.ref(:ConfigurationResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def show(conn, %{"external_id" => external_id}) do
    configuration = Configurations.get_configuration_by_external_id!(external_id, [:secrets])
    render(conn, "show.json", configuration: configuration)
  rescue
    _e in Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> put_view(ErrorView)
      |> render("404.json")
  end

  swagger_path :update do
    description("Updates content")
    produces("application/json")

    parameters do
      external_id(:path, :string, "external_id of content", required: true)

      configuration(
        :body,
        Schema.ref(:UpdateConfiguration),
        "Parameters used to update a content"
      )
    end

    response(200, "OK", Schema.ref(:ConfigurationResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def update(conn, %{"external_id" => external_id, "configuration" => configuration_params}) do
    claims = conn.assigns[:current_resource]
    configuration = Configurations.get_configuration_by_external_id!(external_id)

    with {:can, true} <- {:can, can?(claims, update(configuration))},
         {:ok, %Configuration{} = configuration} <-
           Configurations.update_configuration(configuration, configuration_params) do
      render(conn, "show.json", configuration: configuration)
    end
  end

  swagger_path :delete do
    description("Deletes a configuration")

    parameters do
      external_id(:path, :string, "Configuration external id", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def delete(conn, %{"external_id" => external_id}) do
    claims = conn.assigns[:current_resource]
    configuration = Configurations.get_configuration_by_external_id!(external_id)

    with {:can, true} <- {:can, can?(claims, delete(configuration))},
         {:ok, %Configuration{}} <- Configurations.delete_configuration(configuration) do
      send_resp(conn, :no_content, "")
    end
  end
end
