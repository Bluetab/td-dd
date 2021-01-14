defmodule TdDdWeb.UnitEventController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdDd.Lineage.Units

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    TdDdWeb.SwaggerDefinitions.unit_swagger_definitions()
  end

  swagger_path :index do
    description("List of Unit Events")
    response(200, "OK", Schema.ref(:UnitEventsResponse))
  end

  def index(conn, %{"unit_name" => name}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, list(Unit))},
         {:ok, %Units.Unit{events: events}} <- Units.get_by(name: name, preload: :events) do
      render(conn, "index.json", events: events)
    end
  end
end
