defmodule TdDdWeb.CsvBulkUpdateEventController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.DataStructures.BulkUpdate
  alias TdDd.DataStructures.CsvBulkUpdateEvents

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    TdDdWeb.SwaggerDefinitions.lineage_swagger_definitions()
  end

  swagger_path :index do
    description("List of Lineage Events")
    response(200, "OK", Schema.ref(:LineageEventsResponse))
  end

  def index(conn, _params) do
    with %{user_id: user_id} = claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(BulkUpdate, :bulk_upload, claims) do
      render(conn, "index.json", %{
        csv_bulk_update_events: CsvBulkUpdateEvents.get_by_user_id(user_id)
      })
    end
  end
end
