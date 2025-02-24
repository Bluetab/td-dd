defmodule TdDdWeb.FileBulkUpdateEventController do
  use TdDdWeb, :controller

  alias TdDd.DataStructures.BulkUpdate
  alias TdDd.DataStructures.FileBulkUpdateEvents

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, _params) do
    with %{user_id: user_id} = claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(BulkUpdate, :bulk_upload, claims) do
      render(conn, "index.json", %{
        file_bulk_update_events: FileBulkUpdateEvents.get_by_user_id(user_id)
      })
    end
  end
end
