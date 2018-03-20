defmodule TdDqWeb.QualityControlTypeController do
  use TdDqWeb, :controller
  use PhoenixSwagger

  alias Poison, as: JSON
  alias TdDqWeb.SwaggerDefinitions

  action_fallback TdDqWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.quality_control_type_definitions()
  end

  swagger_path :index do
    get "/quality_control_types"
    description "List Quality Control Types"
    response 200, "OK", Schema.ref(:QualityControlTypesResponse)
  end

  def index(conn, _params) do
    quality_control_types = get_quality_control_types()
    render(conn, "index.json", quality_control_types: quality_control_types)
  end

  defp get_quality_control_types do
    file_name = Application.get_env(:td_dq, :qc_types_file)
    file_path = Path.join(:code.priv_dir(:td_dq), file_name)
    file_path
    |> File.read!
    |> JSON.decode!
  end
end
