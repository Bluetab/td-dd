defmodule TdDqWeb.ImplementationUploadController do
  use TdDqWeb, :controller

  alias Plug.Upload
  alias TdDq.CSV.ImplementationsReader

  action_fallback(TdDqWeb.FallbackController)

  @default_lang Application.compile_env(:td_dd, :lang)

  def create(conn, %{"implementations" => %Upload{path: path, filename: _filename}} = params) do
    lang = Map.get(params, "lang", @default_lang)

    auto_publish = params |> Map.get("auto_publish", "false") |> String.to_existing_atom()
    claims = conn.assigns[:current_resource]

    with stream <- File.stream!(path, [:trim_bom]),
         {:ok, %{ids: ids, errors: errors}} <-
           ImplementationsReader.read_csv(claims, stream, auto_publish, lang) do
      render(conn, "create.json", ids: ids, errors: errors)
    else
      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", error: error)
    end
  end
end
