defmodule TdDdWeb.CsvBulkUpdateEventView do
  use TdDdWeb, :view

  def render("index.json", %{csv_bulk_update_events: events}) do
    render_many(events, __MODULE__, "show.json")
  end

  def render("show.json", %{csv_bulk_update_event: event}) do
    Map.take(event, [
      :user_id,
      :response,
      :csv_hash,
      :status,
      :task_reference,
      :message,
      :inserted_at,
      :filename
    ])
  end
end
