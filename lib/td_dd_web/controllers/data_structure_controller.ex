defmodule TdDdWeb.DataStructureController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias Ecto
  alias Jason, as: JSON
  alias TdCache.TaxonomyCache
  alias TdDd.Audit.AuditSupport
  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug
  alias TdDd.CSV.Download
  alias TdDd.DataStructures
  alias TdDd.DataStructures.BulkUpdate
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.Search
  alias TdDdWeb.SwaggerDefinitions

  require Logger

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.data_structure_swagger_definitions()
  end

  swagger_path :index do
    description("List Data Structures")
    response(200, "OK", Schema.ref(:DataStructuresResponse))
  end

  def index(conn, _params) do
    %{results: data_structures} = do_index(conn, %{}, 0, 10_000)
    render(conn, "index.json", data_structures: data_structures)
  end

  swagger_path :create do
    description("Creates Data Structure")
    produces("application/json")

    parameters do
      data_structure(:body, Schema.ref(:DataStructureCreate), "Data Structure create attrs")
    end

    response(201, "OK", Schema.ref(:DataStructureResponse))
    response(400, "Client Error")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def create(conn, %{"data_structure" => attrs}) do
    user = conn.assigns[:current_user]
    names = TaxonomyCache.get_domain_name_to_id_map()
    external_ids = TaxonomyCache.get_domain_external_id_to_id_map()

    creation_params =
      attrs
      |> Map.put("last_change_by", get_current_user_id(conn))
      |> Map.put("metadata", %{})
      |> DataStructures.put_domain_id(names, external_ids)

    with domain_id <- Map.get(creation_params, "domain_id"),
         true <- can?(user, create_data_structure(domain_id)),
         {:ok, %DataStructure{id: id}} <- DataStructures.create_data_structure(creation_params) do
      AuditSupport.create_data_structure(conn, id, attrs)
      data_structure = get_data_structure(id)

      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
      )
      |> render("show.json", data_structure: data_structure)
    else
      false -> render_error(conn, :forbidden)
      _error -> render_error(conn, :unprocessable_entity)
    end
  end

  @lift_attrs [:class, :description, :metadata, :group, :name, :type, :deleted_at]
  @enrich_attrs [
    :ancestry,
    :children,
    :data_field_degree,
    :data_field_links,
    :data_fields,
    :domain,
    :links,
    :parents,
    :relations,
    :siblings,
    :system,
    :versions,
    :metadata_versions
  ]

  defp get_data_structure(id) do
    case DataStructures.get_latest_version(id, @enrich_attrs) do
      nil ->
        DataStructures.get_data_structure!(id)

      dsv ->
        dsv
        |> Map.get(:data_structure)
        |> Map.merge(Map.take(dsv, @enrich_attrs))
        |> Map.merge(Map.take(dsv, @lift_attrs))
    end
  end

  defp do_render_data_structure(conn, _user, nil) do
    render_error(conn, :not_found)
  end

  defp do_render_data_structure(conn, user, data_structure) do
    if can?(user, view_data_structure(data_structure)) do
      user_permissions = %{
        update: can?(user, update_data_structure(data_structure)),
        confidential: can?(user, manage_confidential_structures(data_structure)),
        view_profiling_permission: can?(user, view_data_structures_profile(data_structure))
      }

      render(conn, "show.json", data_structure: data_structure, user_permissions: user_permissions)
    else
      render_error(conn, :forbidden)
    end
  end

  swagger_path :update do
    description("Update Data Structures")
    produces("application/json")

    parameters do
      id(:path, :integer, "Data Structure ID", required: true)
      data_field(:body, Schema.ref(:DataStructureUpdate), "Data Structure update attrs")
    end

    response(201, "OK", Schema.ref(:DataStructureResponse))
    response(400, "Client Error")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{"id" => id, "data_structure" => attrs}) do
    user = conn.assigns[:current_user]

    data_structure_old = DataStructures.get_data_structure!(id)

    manage_confidential_structures =
      can?(user, manage_confidential_structures(data_structure_old))

    names = TaxonomyCache.get_domain_name_to_id_map()
    external_ids = TaxonomyCache.get_domain_external_id_to_id_map()

    update_params =
      attrs
      |> check_confidential_field(manage_confidential_structures)
      |> Map.put("last_change_by", get_current_user_id(conn))
      |> DataStructures.put_domain_id(names, external_ids)

    with true <- can?(user, update_data_structure(data_structure_old)),
         {:ok, %DataStructure{} = data_structure} <-
           DataStructures.update_data_structure(data_structure_old, update_params, reindex: true) do
      AuditSupport.update_data_structure(conn, data_structure_old, attrs)

      data_structure = get_data_structure(data_structure.id)
      do_render_data_structure(conn, user, data_structure)
    else
      false -> render_error(conn, :forbidden)
      _error -> render_error(conn, :unprocessable_entity)
    end
  end

  defp check_confidential_field(params, true), do: params
  defp check_confidential_field(params, false), do: Map.drop(params, ["confidential"])

  swagger_path :delete do
    description("Delete Data Structure")
    produces("application/json")

    parameters do
      id(:path, :integer, "Data Structure ID", required: true)
    end

    response(204, "No Content")
    response(400, "Client Error")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns[:current_user]
    data_structure = DataStructures.get_data_structure!(id)

    with true <- can?(user, delete_data_structure(data_structure)),
         {:ok, %DataStructure{}} <- DataStructures.delete_data_structure(data_structure) do
      AuditSupport.delete_data_structure(conn, id)
      send_resp(conn, :no_content, "")
    else
      false -> render_error(conn, :forbidden)
      _error -> render_error(conn, :unprocessable_entity)
    end
  end

  defp get_current_user_id(conn) do
    GuardianPlug.current_resource(conn).id
  end

  swagger_path :search do
    description("Data Structures")

    parameters do
      search(
        :body,
        Schema.ref(:DataStructureSearchRequest),
        "Search query parameter"
      )
    end

    response(200, "OK", Schema.ref(:DataStructuresResponse))
  end

  def search(conn, params) do
    %{results: data_structures, aggregations: aggregations, total: total} = do_index(conn, params)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("index.json", data_structures: data_structures, filters: aggregations)
  end

  swagger_path :get_system_structures do
    description("List System Root Data Structures")

    parameters do
      system_id(:path, :string, "List of organizational units", required: true)
    end

    response(200, "OK", Schema.ref(:DataStructuresResponse))
  end

  def get_system_structures(conn, params) do
    user = conn.assigns[:current_user]
    permission = conn.assigns[:search_permission]

    %{results: data_structures, total: total} =
      params
      |> Map.put("filters", %{system_id: String.to_integer(Map.get(params, "system_id"))})
      |> Map.put(:without, ["path", "deleted_at"])
      |> Search.search_data_structures(user, permission, 0, 1_000)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("index.json", data_structures: data_structures)
  end

  swagger_path :bulk_update do
    description("Bulk Update of extra info structures")
    produces("application/json")

    parameters do
      bulk_update_request(
        :body,
        Schema.ref(:BulkUpdateRequest),
        "Search query filter parameters and update attributes"
      )
    end

    response(200, "OK", Schema.ref(:BulkUpdateResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Error while bulk update")
  end

  def bulk_update(conn, %{
        "bulk_update_request" => %{
          "update_attributes" => update_attributes,
          "search_params" => search_params
        }
      }) do
    user = conn.assigns[:current_user]
    permission = conn.assigns[:search_permission]

    with true <- user.is_admin,
         %{results: results} <- search_all_structures(user, permission, search_params),
         {:ok, response} <- BulkUpdate.update_all(user, results, update_attributes) do
      body = JSON.encode!(%{data: %{message: response}})

      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(200, body)
    else
      false ->
        render_error(conn, :forbidden)

      {:error, error} ->
        Logger.info("While updating data structures... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_resp_content_type("application/json", "utf-8")
        |> send_resp(422, JSON.encode!(%{error: error}))

      error ->
        Logger.info("Unexpected error while updating data structures... #{inspect(error)}")
        render_error(conn, :unprocessable_entity)
    end
  end

  defp search_all_structures(user, permission, params) do
    params
    |> Map.drop(["page", "size"])
    |> Search.search_data_structures(user, permission, 0, 10_000)
  end

  swagger_path :csv do
    description("Download CSV of structures")
    produces("application/json")

    parameters do
      search(
        :body,
        Schema.ref(:DataStructureSearchRequest),
        "Search query parameter"
      )
    end

    response(200, "OK")
    response(403, "User is not authorized to perform this action")
    response(422, "Error while CSV download")
  end

  def csv(conn, params) do
    header_labels =
      params
      |> Map.get("header_labels", %{})

    params =
      params
      |> Map.drop(["header_labels"])
      |> Map.drop(["page", "size"])

    permission = conn.assigns[:search_permission]
    user = conn.assigns[:current_user]

    %{results: data_structures} = search_all_structures(user, permission, params)

    case data_structures do
      [] ->
        send_resp(conn, :no_content, "")

      _ ->
        conn
        |> put_resp_content_type("text/csv", "utf-8")
        |> put_resp_header("content-disposition", "attachment; filename=\"structures.zip\"")
        |> send_resp(200, Download.to_csv(data_structures, header_labels))
    end
  end

  defp do_index(conn, search_params, page \\ 0, size \\ 50) do
    user = conn.assigns[:current_user]
    permission = conn.assigns[:search_permission]

    page = search_params |> Map.get("page", page)
    size = search_params |> Map.get("size", size)

    search_params
    |> Map.put(:without, ["deleted_at"])
    |> Map.drop(["page", "size"])
    |> Search.search_data_structures(user, permission, page, size)
  end
end
