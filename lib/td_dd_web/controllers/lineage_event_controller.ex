defmodule TdDdWeb.LineageEventController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdDd.Lineage.LineageEvents

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    TdDdWeb.SwaggerDefinitions.unit_swagger_definitions()
  end

  swagger_path :index do
    description("List of Lineage Events")
    response(200, "OK", Schema.ref(:UnitEventsResponse))
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]
    with %{user_id: user_id} = _claims <- conn.assigns[:current_resource],
          {:can, true} <- {:can, can?(claims, list(Lineage))} do
      render(conn, "index.json", %{lineage_events: LineageEvents.pending_by_user_id(user_id)})
    end
  end
end
