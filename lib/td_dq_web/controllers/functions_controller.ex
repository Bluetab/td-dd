defmodule TdDqWeb.FunctionsController do
  use TdDqWeb, :controller

  alias TdDq.Functions

  action_fallback(TdDqWeb.FallbackController)

  def update(conn, params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Functions, :replace, claims),
         {:ok, _multi} <- Functions.replace_all(params) do
      functions = Functions.list_functions()

      conn
      |> put_view(TdDqWeb.FunctionView)
      |> render("index.json", functions: functions)
    end
  end
end
