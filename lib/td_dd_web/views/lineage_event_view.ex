defmodule TdDdWeb.LineageEventView do
  use TdDdWeb, :view

  def render("index.json", %{lineage_events: events}) do
    render_many(events, __MODULE__, "show.json")
  end

  def render("show.json", %{lineage_event: event}) do
    Map.take(event, [
      :user_id,
      :graph_id,
      :graph_data,
      :graph_hash,
      :status,
      :task_reference,
      :type,
      :message,
      :inserted_at
    ])
  end
end
