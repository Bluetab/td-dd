defmodule TdDdWeb.CsvBulkUpdateEventController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures.CsvBulkUpdateEvents
  alias TdDd.DataStructures.DataStructure

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
         {:can, true} <- {:can, can?(claims, list_bulk_update_events(DataStructure))} do
      render(conn, "index.json", %{csv_bulk_update_events: CsvBulkUpdateEvents.get_by_user_id(user_id)})
    end
  end
end
