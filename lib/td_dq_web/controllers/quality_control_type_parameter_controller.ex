defmodule TdDqWeb.QualityControlTypeParameterController do
  use TdDqWeb, :controller
  use PhoenixSwagger

  alias TdDqWeb.SwaggerDefinitions
  alias TdDq.QualityControls.QualityControl

  action_fallback TdDqWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.quality_control_type_parameters_definitions()
  end

  swagger_path :index do
    get "/quality_control_type_parameters?quality_control_type_name={type_name}"
    description "Lists quality control type paramaters"
    produces "application/json"
    parameters do
      type_name :path, :string, "Quality Control Type name", required: true
    end
    response 200, "Ok", Schema.ref(:QualityControlTypeParamsResponse)
    response 400, "Client Error"
  end
  def index(conn, %{"quality_control_type_name" => qc_type_name}) do
    qc_types =  QualityControl.get_quality_control_types()
    type_info = Enum.find(qc_types, &(&1["type_name"] == qc_type_name))
    render conn, "quality_control_type_parameters.json", quality_control_type_parameters: type_info["type_parameters"]
  end

end
