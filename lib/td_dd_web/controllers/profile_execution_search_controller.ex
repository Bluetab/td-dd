defmodule TdDdWeb.ProfileExecutionSearchController do
  use TdDdWeb, :controller

  alias TdDdWeb.ProfileExecutionController

  action_fallback(TdDdWeb.FallbackController)

  def create(conn, %{} = params) do
    conn
    |> put_view(TdDdWeb.ProfileExecutionView)
    |> ProfileExecutionController.index(params)
  end
end
