defmodule TdDdWeb.DataStructureView do
  use TdDdWeb, :view
  alias TdDdWeb.DataStructureView

  def render("index.json", %{data_structures: data_structures}) do
    %{data: render_many(data_structures, DataStructureView, "data_structure.json")}
  end

  def render("show.json", %{data_structure: data_structure}) do
    %{data: render_one(data_structure, DataStructureView, "data_structure.json")}
  end

  def render("data_structure.json", %{data_structure: data_structure}) do
    %{id: data_structure.id,
      system: data_structure.system,
      group: data_structure.group,
      name: data_structure.name,
      description: data_structure.description,
      last_change_at: data_structure.last_change_at,
      last_change_by: data_structure.last_change_by}
  end
end
