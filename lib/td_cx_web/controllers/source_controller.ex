defmodule TdCxWeb.SourceController do
  use TdCxWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdCx.Sources
  alias TdCx.Sources.Source
  alias TdCxWeb.SwaggerDefinitions

  action_fallback(TdCxWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.source_definitions()
  end

  swagger_path :index do
    description("Get sources of the given type")
    produces("application/json")

    parameters do
      type(:query, :string, "type of source", required: false)
    end

    response(200, "OK", Schema.ref(:SourcesResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def index(conn, %{"type" => source_type} = attrs) do
    claims = conn.assigns[:current_resource]
    sources = Sources.list_sources_by_source_type(source_type)

    case can?(claims, view_secrets(attrs)) do
      true ->
        sources = Enum.map(sources, &Sources.enrich_secrets(&1))
        render(conn, "index.json", sources: sources)

      _ ->
        render(conn, "index.json", sources: sources)
    end
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, list(Source))},
         sources <- Sources.list_sources(deleted: false) do
      render(conn, "index.json", sources: sources)
    end
  end

  swagger_path :create do
    description("Creates a new source")
    produces("application/json")

    parameters do
      source(:body, Schema.ref(:CreateSource), "Parameters used to create a source")
    end

    response(200, "OK", Schema.ref(:SourceResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def create(conn, %{"source" => source_params}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, create(%Source{}))},
         {:ok, %Source{} = source} <- Sources.create_or_update_source(source_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.source_path(conn, :show, source))
      |> render("show.json", source: source)
    end
  end

  swagger_path :show do
    description("Get source with the given external_id")
    produces("application/json")

    parameters do
      external_id(:path, :string, "external id of source", required: true)
    end

    response(200, "OK", Schema.ref(:SourceResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def show(conn, %{"external_id" => external_id}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, show(%Source{}))},
         %Source{} = source <- Sources.get_source(external_id),
         %Source{} = source <- Sources.enrich_secrets(claims, source),
         job_types <- Sources.job_types(claims, source) do
      render(conn, "show.json", source: source, job_types: job_types)
    end
  end

  swagger_path :update do
    description("Updates config or secrets of source")
    produces("application/json")

    parameters do
      external_id(:path, :string, "external_id of source", required: true)
      merge_content(:body, :string, "if true, the body content will be merged on top of the current value")
      source(:body, Schema.ref(:UpdateSource), "Parameters used to update a source")
    end

    response(200, "OK", Schema.ref(:SourceResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def update(conn, %{"external_id" => external_id, "source" => source_params}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, update(%Source{}))},
         %Source{} = source <- Sources.get_source(external_id),
         {:ok, %Source{} = source} <- Sources.update_source(source, source_params) do
      render(conn, "show.json", source: source)
    end
  end

  def update(conn, %{"external_id" => external_id, "source_config" => config}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, update(%Source{}))},
         %Source{} = source <- Sources.get_source(external_id),
         {:ok, %Source{} = source} <- Sources.update_source_config(source, config) do
      render(conn, "show.json", source: source)
    end
  end

  swagger_path :delete do
    description("Deletes a source")

    parameters do
      external_id(:path, :string, "Source external id", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def delete(conn, %{"external_id" => external_id}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, delete(%Source{}))},
         %Source{} = source <- Sources.get_source!(external_id: external_id, preload: :jobs),
         {:ok, %Source{} = _source} <- Sources.delete_source(source) do
      send_resp(conn, :no_content, "")
    end
  end
end
