defmodule TdDqWeb.QualityControlTypeView do
  use TdDqWeb, :view
  alias TdDqWeb.QualityControlTypeView

  def render("index.json", %{quality_control_types: quality_control_types}) do
    %{data: render_many(quality_control_types, QualityControlTypeView, "quality_control_type.json")}
  end

  def render("quality_control_type.json", %{quality_control_type: quality_control_type}) do
    %{type_name: quality_control_type["type_name"]}
  end

end
