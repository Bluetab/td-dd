defmodule TdCxWeb.SourceController do
  use TdCxWeb, :controller

  alias TdCx.Sources
  alias TdCx.Sources.Source

  action_fallback(TdCxWeb.FallbackController)

  def index(conn, %{"type" => source_type} = params) do
    claims = conn.assigns[:current_resource]
    sources = Sources.list_sources_by_source_type(source_type)

    case Bodyguard.permit(Sources, :view_secrets, claims, params) do
      :ok ->
        sources = Enum.map(sources, &Sources.enrich_secrets(&1))
        render(conn, "index.json", sources: sources)

      _ ->
        render(conn, "index.json", sources: sources)
    end
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Sources, :query, claims),
         sources <- Sources.list_sources(deleted: false) do
      render(conn, "index.json", sources: sources)
    end
  end

  def create(conn, %{"source" => source_params}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Sources, :create, claims),
         {:ok, %Source{} = source} <- Sources.create_or_update_source(source_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.source_path(conn, :show, source))
      |> render("show.json", source: source)
    end
  end

  def show(conn, %{"external_id" => external_id}) do
    claims = conn.assigns[:current_resource]

    with %Source{} = source <- Sources.get_source(external_id),
         :ok <- Bodyguard.permit(Sources, :view, claims, source),
         %Source{} = source <- Sources.enrich_secrets(claims, source) do
      job_types = Sources.job_types(source)
      render(conn, "show.json", source: source, job_types: job_types)
    end
  end

  def update(conn, %{"external_id" => external_id, "source" => source_params}) do
    claims = conn.assigns[:current_resource]

    with %Source{} = source <- Sources.get_source(external_id),
         :ok <- Bodyguard.permit(Sources, :update, claims, source),
         {:ok, %Source{} = source} <- Sources.update_source(source, source_params) do
      render(conn, "show.json", source: source)
    end
  end

  def update(conn, %{"external_id" => external_id, "source_config" => config}) do
    claims = conn.assigns[:current_resource]

    with %Source{} = source <- Sources.get_source(external_id),
         :ok <- Bodyguard.permit(Sources, :update, claims, source),
         {:ok, %Source{} = source} <- Sources.update_source_config(source, config) do
      render(conn, "show.json", source: source)
    end
  end

  def delete(conn, %{"external_id" => external_id}) do
    claims = conn.assigns[:current_resource]

    with %Source{} = source <- Sources.get_source!(external_id: external_id, preload: :jobs),
         :ok <- Bodyguard.permit(Sources, :delete, claims, source),
         {:ok, %Source{} = _source} <- Sources.delete_source(source) do
      send_resp(conn, :no_content, "")
    end
  end
end
