defmodule TdDqWeb.RuleResultSearchController do
  use TdDqWeb, :controller

  alias TdDqWeb.RuleResultController

  action_fallback(TdDqWeb.FallbackController)

  def create(conn, %{} = params) do
    conn
    |> put_view(TdDqWeb.RuleResultView)
    |> RuleResultController.index(params)
  end
end
