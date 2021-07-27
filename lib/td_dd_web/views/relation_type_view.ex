defmodule TdDdWeb.RelationTypeView do
  use TdDdWeb, :view
  alias TdDdWeb.RelationTypeView

  def render("index.json", %{relation_types: relation_types}) do
    %{data: render_many(relation_types, RelationTypeView, "relation_type.json")}
  end

  def render("show.json", %{relation_type: relation_type}) do
    %{data: render_one(relation_type, RelationTypeView, "relation_type.json")}
  end

  def render("relation_type.json", %{relation_type: relation_type}) do
    %{id: relation_type.id, name: relation_type.name, description: relation_type.description}
  end
end
