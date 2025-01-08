defmodule TdDdWeb.CsvBulkUpdateEventController do
  use TdDdWeb, :controller

  alias TdDd.DataStructures.BulkUpdate
  alias TdDd.DataStructures.CsvBulkUpdateEvents

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, _params) do
    with %{user_id: user_id} = claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(BulkUpdate, :bulk_upload, claims) do
      render(conn, "index.json", %{
        csv_bulk_update_events: CsvBulkUpdateEvents.get_by_user_id(user_id)
      })
    end
  end
end
