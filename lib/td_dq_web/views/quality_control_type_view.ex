defmodule TdDqWeb.QualityControlTypeView do
  use TdDqWeb, :view
  alias TdDqWeb.QualityControlTypeView

  def render("index.json", %{quality_control_types: quality_control_types}) do
    quality_control_types
  end
end
