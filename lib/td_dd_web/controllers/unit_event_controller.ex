defmodule TdDdWeb.UnitEventController do
  use TdDdWeb, :controller

  alias TdDd.Lineage.Units

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, %{"unit_name" => name}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Units, :list, claims),
         {:ok, %Units.Unit{events: events}} <- Units.get_by(name: name, preload: :events) do
      render(conn, "index.json", events: events)
    end
  end
end
