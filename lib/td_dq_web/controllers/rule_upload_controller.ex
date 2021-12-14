defmodule TdDqWeb.RuleUploadController do
  use TdDqWeb, :controller

  alias Plug.Upload
  alias TdDq.CSV.RulesReader

  action_fallback(TdDqWeb.FallbackController)

  def create(conn, %{"rules" => %Upload{path: path, filename: _filename}}) do
    claims = conn.assigns[:current_resource]

    with stream <- File.stream!(path, [:trim_bom]),
         {:ok, %{ids: ids, errors: errors}} <- RulesReader.reader_csv(claims, stream) do
      render(conn, "create.json", ids: ids, errors: errors)
    else
      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", error: error)
    end
  end
end
