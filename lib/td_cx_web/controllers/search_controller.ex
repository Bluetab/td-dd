defmodule TdCxWeb.SearchController do
  use TdCxWeb, :controller
  import Canada, only: [can?: 2]
  use PhoenixSwagger
  alias TdCx.Jobs.Job
  alias TdCxWeb.ErrorView

  @index_worker Application.compile_env(:td_dd, :cx_index_worker)

  swagger_path :reindex_all do
    description("Reindex all ES indexes with DB content")
    produces("application/json")
    response(202, "Accepted")
    response(403, "Unauthorized")
    response(500, "Client Error")
  end

  def reindex_all(conn, _params) do
    claims = conn.assigns[:current_resource]

    if can?(claims, reindex_all(Job)) do
      @index_worker.reindex(:all)
      send_resp(conn, :accepted, "")
    else
      conn
      |> put_status(:forbidden)
      |> put_view(ErrorView)
      |> render("403.json")
    end
  end
end
