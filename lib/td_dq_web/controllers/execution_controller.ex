defmodule TdDqWeb.ExecutionController do
  use TdDqWeb, :controller

  alias TdDq.Executions

  action_fallback(TdDqWeb.FallbackController)

  def index(conn, params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Executions, :list_executions, claims),
         executions <-
           Executions.list_executions(params, preload: [:implementation, :result, :group]) do
      render(conn, "index.json", executions: executions)
    end
  end
end
