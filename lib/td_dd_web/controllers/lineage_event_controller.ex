defmodule TdDdWeb.LineageEventController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.Lineage.LineageEvent
  alias TdDd.Lineage.LineageEvents

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
         :ok <- Bodyguard.permit(LineageEvents, :list, claims, LineageEvent) do
      render(conn, "index.json", %{lineage_events: LineageEvents.get_by_user_id(user_id)})
    end
  end
end
