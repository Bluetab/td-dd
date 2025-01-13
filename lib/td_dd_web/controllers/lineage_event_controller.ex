defmodule TdDdWeb.LineageEventController do
  use TdDdWeb, :controller

  alias TdDd.Lineage.LineageEvent
  alias TdDd.Lineage.LineageEvents

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, _params) do
    with %{user_id: user_id} = claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(LineageEvents, :list, claims, LineageEvent) do
      render(conn, "index.json", %{lineage_events: LineageEvents.get_by_user_id(user_id)})
    end
  end
end
