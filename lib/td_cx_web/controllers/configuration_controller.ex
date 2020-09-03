defmodule TdCxWeb.ConfigurationController do
  use TdCxWeb, :controller

  import Canada, only: [can?: 2]

  alias TdCx.Configurations
  alias TdCx.Configurations.Configuration
  alias TdCxWeb.ErrorView

  action_fallback(TdCxWeb.FallbackController)

  def index(conn, _params) do
    configurations = Configurations.list_configurations()
    render(conn, "index.json", configurations: configurations)
  end

  def create(conn, %{"configuration" => configuration_params}) do
    user = conn.assigns[:current_user]

    with {:can, true} <- {:can, can?(user, create(Configuration))},
         {:ok, %Configuration{} = configuration} <-
           Configurations.create_configuration(configuration_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.configuration_path(conn, :show, configuration))
      |> render("show.json", configuration: configuration)
    end
  end

  def show(conn, %{"external_id" => external_id}) do
    configuration = Configurations.get_configuration_by_external_id!(external_id)
    render(conn, "show.json", configuration: configuration)
  rescue
    _e in Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> put_view(ErrorView)
      |> render("404.json")
  end

  def update(conn, %{"external_id" => external_id, "configuration" => configuration_params}) do
    user = conn.assigns[:current_user]
    configuration = Configurations.get_configuration_by_external_id!(external_id)

    with {:can, true} <- {:can, can?(user, update(configuration))},
         {:ok, %Configuration{} = configuration} <-
           Configurations.update_configuration(configuration, configuration_params) do
      render(conn, "show.json", configuration: configuration)
    end
  end

  def delete(conn, %{"external_id" => external_id}) do
    user = conn.assigns[:current_user]
    configuration = Configurations.get_configuration_by_external_id!(external_id)

    with {:can, true} <- {:can, can?(user, delete(configuration))},
         {:ok, %Configuration{}} <- Configurations.delete_configuration(configuration) do
      send_resp(conn, :no_content, "")
    end
  end
end
