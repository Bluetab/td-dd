defmodule TdDqWeb.QualityControlTypeParameterView do
  use TdDqWeb, :view
  alias TdDqWeb.QualityControlTypeParameterView

  def render("quality_control_type_parameters.json", %{quality_control_type_parameters: nil}) do
    %{data: []}
  end

  def render("quality_control_type_parameters.json", %{quality_control_type_parameters: quality_control_type_parameters}) do
    %{data: render_many(quality_control_type_parameters, QualityControlTypeParameterView, "quality_control_type_parameter.json")}
  end

  def render("quality_control_type_parameter.json", %{quality_control_type_parameter: qc_type_parameter}) do
    %{name: qc_type_parameter["name"],
      type: qc_type_parameter["type"]}
  end

end
