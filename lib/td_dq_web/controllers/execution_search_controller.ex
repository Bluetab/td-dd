defmodule TdDqWeb.ExecutionSearchController do
  use TdDqWeb, :controller

  alias TdDqWeb.ExecutionController

  action_fallback(TdDqWeb.FallbackController)

  def create(conn, %{} = params) do
    conn
    |> put_view(TdDqWeb.ExecutionView)
    |> ExecutionController.index(params)
  end
end
