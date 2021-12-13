defmodule TdDqWeb.ImplementationUploadController do
  use TdDqWeb, :controller

  alias Plug.Upload
  alias TdDq.CSV.ImplementationsReader

  action_fallback(TdDqWeb.FallbackController)

  def create(conn, %{"implementations" => %Upload{path: path, filename: _filename}}) do
    claims = conn.assigns[:current_resource]

    with stream <- File.stream!(path, [:trim_bom]),
         {:ok, %{ids: ids, errors: errors}} <- ImplementationsReader.read_csv(claims, stream) do
      render(conn, "create.json", ids: ids, errors: errors)
    else
      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", error: error)
    end
  end
end
