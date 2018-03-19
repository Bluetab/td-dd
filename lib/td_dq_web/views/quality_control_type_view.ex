defmodule TdDqWeb.QualityControlTypeView do
  use TdDqWeb, :view
  alias TdDqWeb.QualityControlTypeView

  def render("index.json", %{quality_control_types: quality_control_types}) do
    Enum.reduce(quality_control_types, [], &(&2 ++ [&1["type_name"]]))
  end

end
