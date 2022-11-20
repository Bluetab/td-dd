defmodule TdDdWeb.DataStructureLinkController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  action_fallback(TdDdWeb.FallbackController)
  alias TdDd.DataStructures.DataStructureLink
  alias TdDd.DataStructures.DataStructureLinks
  alias TdDdWeb.SwaggerDefinitions

  def swagger_definitions do
    SwaggerDefinitions.data_structure_link_swagger_definitions()
  end

  swagger_path :index do
    description("Show the structure links of a given structure, as either source or target")

    parameters do
      data_structure_id(:path, :integer, "Data structure id", required: true)
    end

    response(200, "OK")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def index(conn, %{"data_structure_id" => data_structure_id} = _params) do
    claims = conn.assigns[:current_resource]

    with links <- DataStructureLinks.all_by_id(data_structure_id),
         :ok <- Bodyguard.permit(DataStructureLinks, :view, claims, links) do
      render(conn, "index.json", data_structure_links: links)
    end
  end

  swagger_path :index_by_external_id do
    description("Show the structure links of a given structure, as either source or target")

    parameters do
      external_id(:query, :string, "Data structure external id", required: true)
    end

    response(200, "OK")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def index_by_external_id(conn, %{"external_id" => external_id}) do
    claims = conn.assigns[:current_resource]

    with links <- DataStructureLinks.all_by_external_id(external_id),
         :ok <- Bodyguard.permit(DataStructureLinks, :view, claims, links) do
      render(conn, "index.json", data_structure_links: links)
    end
  end

  swagger_path :show do
    description("Shows the link between a source and a target structure, searching by their IDs")
    produces("application/json")

    parameters do
      source_id(:path, :integer, "Source data structure id", required: true)
      target_id(:path, :integer, "Target data structure id", required: true)
    end

    response(200, "OK")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def show(conn, %{"source_id" => _source_id, "target_id" => _target_id} = params) do
    claims = conn.assigns[:current_resource]

    with %DataStructureLink{} = link <- DataStructureLinks.get_by(params),
         :ok <- Bodyguard.permit(DataStructureLinks, :view, claims, link) do
      render(conn, "show.json", data_structure_link: link)
    end
  end

  swagger_path :show_by_external_ids do
    description(
      "Shows the link between a source and a target structure, searching by their external IDs"
    )

    produces("application/json")

    parameters do
      source_external_id(:query, :string, "Source data structure external id", required: true)
      target_external_id(:query, :string, "Target data structure external id", required: true)
    end

    response(200, "OK")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def show_by_external_ids(
        conn,
        %{
          "source_external_id" => _source_external_id,
          "target_external_id" => _target_external_id
        } = params
      ) do
    claims = conn.assigns[:current_resource]

    with %DataStructureLink{} = link <- DataStructureLinks.get_by(params),
         :ok <- Bodyguard.permit(DataStructureLinks, :view, claims, link) do
      render(conn, "show.json", data_structure_link: link)
    end
  end

  swagger_path :delete do
    description(
      "Deletes the link between a source and a target structure, searching by their IDs"
    )

    parameters do
      source_id(:path, :integer, "Source data structure ID", required: true)
      target_id(:path, :integer, "Target data structure ID", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def delete(conn, %{"source_id" => _source_id, "target_id" => _target_id} = params) do
    claims = conn.assigns[:current_resource]

    with %DataStructureLink{} = link <- DataStructureLinks.get_by(params),
         :ok <- Bodyguard.permit(DataStructureLinks, :delete, claims, link),
         {:ok, %DataStructureLink{}} <- DataStructureLinks.delete(link) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :delete_by_external_ids do
    description(
      "Deletes the link between a source and a target structure, searching by their external IDs"
    )

    parameters do
      source_external_id(:query, :string, "Source data structure external ID", required: true)
      target_external_id(:query, :string, "Target data structure external ID", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def delete_by_external_ids(
        conn,
        %{
          "source_external_id" => _source_external_id,
          "target_external_id" => _target_external_id
        } = params
      ) do
    claims = conn.assigns[:current_resource]

    with %DataStructureLink{} = link <- DataStructureLinks.get_by(params),
         :ok <- Bodyguard.permit(DataStructureLinks, :delete, claims, link),
         {:ok, %DataStructureLink{}} <- DataStructureLinks.delete(link) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :create do
    description("Data Structure Links bulk creation")
    produces("application/json")

    parameters do
      bulk_data_structure_links(
        :body,
        Schema.ref(:BulkCreateDataStructureLinksRequest),
        "List of DataStructureLink"
      )
    end

    response(201, "Created", Schema.ref(:BulkCreateDataStructureLinksResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def create(conn, %{"data_structure_links" => links}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(DataStructureLinks, :create, claims),
         {:ok, result} <-
           DataStructureLinks.bulk_load(links) do
      conn
      |> put_status(:created)
      |> render("bulk_create.json", result: result)
    end
  end
end
