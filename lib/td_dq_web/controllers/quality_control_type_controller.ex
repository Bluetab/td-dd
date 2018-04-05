defmodule TdDqWeb.QualityControlTypeController do
  use TdDqWeb, :controller
  use PhoenixSwagger

  alias TdDqWeb.SwaggerDefinitions
  alias TdDq.QualityControls.QualityControl

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
    quality_control_types = QualityControl.get_quality_control_types()
    render(conn, "index.json", quality_control_types: quality_control_types)
  end
end
