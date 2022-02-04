defmodule TdDdWeb.LineageEventController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdDd.Lineage.LineageEvents
  alias TdDd.Lineage.Units.Unit

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    TdDdWeb.SwaggerDefinitions.lineage_swagger_definitions()
  end

  swagger_path :index do
    description("List of Lineage Events")
    response(200, "OK", Schema.ref(:LineageEventsResponse))
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with %{user_id: user_id} = _claims <- conn.assigns[:current_resource] do
         #{:can, true} <- {:can, can?(claims, view_lineage)} |> IO.inspect(label: "LINEAGE_EVENT") do
      render(conn, "index.json", %{lineage_events: LineageEvents.get_by_user_id(user_id)})
    end
  end
end
