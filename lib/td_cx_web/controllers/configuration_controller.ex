defmodule TdCxWeb.ConfigurationController do
  use TdCxWeb, :controller

  alias TdCx.Configurations
  alias TdCx.Configurations.Configuration

  action_fallback(TdCxWeb.FallbackController)

  def index(conn, _params) do
    configurations = Configurations.list_configurations()
    render(conn, "index.json", configurations: configurations)
  end

  def create(conn, %{"configuration" => configuration_params}) do
    with {:ok, %Configuration{} = configuration} <-
           Configurations.create_configuration(configuration_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.configuration_path(conn, :show, configuration))
      |> render("show.json", configuration: configuration)
    end
  end

  def show(conn, %{"id" => id}) do
    configuration = Configurations.get_configuration!(id)
    render(conn, "show.json", configuration: configuration)
  end

  def update(conn, %{"id" => id, "configuration" => configuration_params}) do
    configuration = Configurations.get_configuration!(id)

    with {:ok, %Configuration{} = configuration} <-
           Configurations.update_configuration(configuration, configuration_params) do
      render(conn, "show.json", configuration: configuration)
    end
  end

  def delete(conn, %{"id" => id}) do
    configuration = Configurations.get_configuration!(id)

    with {:ok, %Configuration{}} <- Configurations.delete_configuration(configuration) do
      send_resp(conn, :no_content, "")
    end
  end
end
