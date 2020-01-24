defmodule TdCxWeb.EventView do
  use TdCxWeb, :view
  alias TdCxWeb.EventView

  def render("index.json", %{events: events}) do
    %{data: render_many(events, EventView, "event.json")}
  end

  def render("show.json", %{event: event}) do
    %{data: render_one(event, EventView, "event.json")}
  end

  def render("event.json", %{event: event}) do
    %{id: event.id, date: DateTime.to_iso8601(event.date), type: event.type, message: event.message}
  end
end
