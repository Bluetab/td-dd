defmodule TdDdWeb.LabelView do
  use TdDdWeb, :view

  def render("index.json", %{labels: labels}) do
    %{data: render_many(labels, __MODULE__, "show.json")}
  end

  def render("show.json", %{label: label}) do
    %{data: render_one(label, __MODULE__, "label.json")}
  end

  def render("label.json", %{label: label}) do
    Map.take(label, [:id, :name])
  end
end
