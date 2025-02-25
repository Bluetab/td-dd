defmodule TdDdWeb.FileBulkUpdateEventView do
  use TdDdWeb, :view

  def render("index.json", %{file_bulk_update_events: events}) do
    render_many(events, __MODULE__, "show.json")
  end

  def render("show.json", %{file_bulk_update_event: event}) do
    Map.take(event, [
      :user_id,
      :response,
      :hash,
      :status,
      :task_reference,
      :message,
      :inserted_at,
      :filename
    ])
  end
end
