defmodule TdDdWeb.TagView do
  use TdDdWeb, :view

  def render("embedded.json", %{tag: tag}) do
    Map.take(tag, [:id, :name, :description])
  end
end
