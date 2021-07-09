defmodule TdDqWeb.QualityEventView do
  use TdDqWeb, :view

  def render("show.json", %{quality_event: event}) do
    %{data: render_one(event, __MODULE__, "quality_event.json")}
  end

  def render("quality_event.json", %{quality_event: event}) do
    Map.take(event, [:id, :inserted_at, :execution_id, :type, :message])
  end
end
