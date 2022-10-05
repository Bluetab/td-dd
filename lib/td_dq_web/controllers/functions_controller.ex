defmodule TdDqWeb.FunctionsController do
  use TdDqWeb, :controller

  alias TdDq.Functions

  action_fallback(TdDqWeb.FallbackController)

  def show(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Functions, :query, claims) do
      functions = Functions.list_functions()

      render(conn, "show.json", functions: functions)
    end
  end
end
