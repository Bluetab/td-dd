defmodule TdCxWeb.SourceController do
  use TdCxWeb, :controller

  alias TdCx.Sources
  alias TdCx.Sources.Source

  action_fallback TdCxWeb.FallbackController

  def index(conn, _params) do
    sources = Sources.list_sources()
    render(conn, "index.json", sources: sources)
  end

  def create(conn, %{"source" => source_params}) do
    with {:ok, %Source{} = source} <- Sources.create_source(source_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.source_path(conn, :show, source))
      |> render("show.json", source: source)
    end
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns[:current_user]
    source = Sources.get_source!(id)

    case user.user_name == source.type do
      true ->
        source = Sources.enrich_secrets(source)
        render(conn, "show_secrets.json", source: source)
        _ ->
          render(conn, "show.json", source: source)
    end
  end

  def update(conn, %{"id" => id, "source" => source_params}) do

    source = Sources.get_source!(id)
    with {:ok, %Source{} = source} <- Sources.update_source(source, source_params) do
      render(conn, "show.json", source: source)
    end
  end

  def delete(conn, %{"id" => id}) do
    source = Sources.get_source!(id)

    with {:ok, %Source{}} <- Sources.delete_source(source) do
      send_resp(conn, :no_content, "")
    end
  end
end
