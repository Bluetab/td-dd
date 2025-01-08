defmodule TdCxWeb.ConfigurationController do
  use TdCxWeb, :controller

  alias TdCx.Configurations
  alias TdCx.Configurations.Configuration

  action_fallback(TdCxWeb.FallbackController)

  def index(conn, params) do
    claims = conn.assigns[:current_resource]

    configurations = Configurations.list_configurations(claims, params)
    render(conn, "index.json", configurations: configurations)
  end

  def create(conn, %{"configuration" => configuration_params}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Configurations, :create, claims),
         {:ok, %Configuration{} = configuration} <-
           Configurations.create_configuration(configuration_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.configuration_path(conn, :show, configuration))
      |> render("show.json", configuration: configuration)
    end
  end

  def show(conn, %{"external_id" => external_id}) do
    claims = conn.assigns[:current_resource]

    configuration = Configurations.get_configuration_by_external_id!(claims, external_id)
    render(conn, "show.json", configuration: configuration)
  end

  def update(conn, %{"external_id" => external_id, "configuration" => configuration_params}) do
    claims = conn.assigns[:current_resource]
    configuration = Configurations.get_configuration_by_external_id!(external_id)

    with :ok <- Bodyguard.permit(Configurations, :update, claims, configuration),
         {:ok, %Configuration{} = configuration} <-
           Configurations.update_configuration(configuration, configuration_params) do
      render(conn, "show.json", configuration: configuration)
    end
  end

  def delete(conn, %{"external_id" => external_id}) do
    claims = conn.assigns[:current_resource]
    configuration = Configurations.get_configuration_by_external_id!(external_id)

    with :ok <- Bodyguard.permit(Configurations, :delete, claims, configuration),
         {:ok, %Configuration{}} <- Configurations.delete_configuration(configuration) do
      send_resp(conn, :no_content, "")
    end
  end
end
