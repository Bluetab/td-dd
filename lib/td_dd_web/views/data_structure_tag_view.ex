defmodule TdDdWeb.DataStructureTagView do
  use TdDdWeb, :view

  def render("embedded.json", %{data_structure_tag: data_structure_tag}) do
    Map.take(data_structure_tag, [:id, :name, :description])
  end
end
