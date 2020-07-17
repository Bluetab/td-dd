defmodule TdDdWeb.DataStructureController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias Ecto
  alias Jason, as: JSON
  alias TdCache.TaxonomyCache
  alias TdDd.CSV.Download
  alias TdDd.DataStructures
  alias TdDd.DataStructures.BulkUpdate
  alias TdDd.DataStructures.Search
  alias TdDdWeb.SwaggerDefinitions

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
    %{id: user_id} = user = conn.assigns[:current_user]
    data_structure_old = DataStructures.get_data_structure!(id)

    manage_confidential_structures =
      can?(user, manage_confidential_structures(data_structure_old))

    external_ids = TaxonomyCache.get_domain_external_id_to_id_map()

    update_params =
      attrs
      |> check_confidential_field(manage_confidential_structures)
      |> Map.put("last_change_by", user_id)
      |> DataStructures.put_domain_id(external_ids)

    with {:can, true} <- {:can, can?(user, update_data_structure(data_structure_old))},
         {:ok, %{data_structure: data_structure}} <-
           DataStructures.update_data_structure(data_structure_old, update_params, user) do
      data_structure = get_data_structure(data_structure.id)
      do_render_data_structure(conn, user, data_structure)
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

    with {:can, true} <- {:can, can?(user, delete_data_structure(data_structure))},
         {:ok, %{data_structure: _deleted_data_structure}} <-
           DataStructures.delete_data_structure(data_structure, user) do
      send_resp(conn, :no_content, "")
    end
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
    response(422, "Error during bulk update")
  end

  def bulk_update(conn, %{
        "bulk_update_request" => %{
          "search_params" => search_params,
          "update_attributes" => update_params
        }
      }) do
    user = conn.assigns[:current_user]
    permission = conn.assigns[:search_permission]

    with {:can, true} <- {:can, user.is_admin},
         %{results: results} <- search_all_structures(user, permission, search_params),
         ids <- Enum.map(results, & &1.id),
         {:ok, %{updates: updates}} <- BulkUpdate.update_all(ids, update_params, user) do
      body = JSON.encode!(%{data: %{message: Map.keys(updates)}})

      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(:ok, body)
    end
  end

  defp search_all_structures(user, permission, params) do
    params
    |> Map.put(:without, ["deleted_at"])
    |> Map.drop(["page", "size"])
    |> Search.search_data_structures(user, permission, 0, 10_000)
  end

  swagger_path :csv do
    description("Download CSV of structures")
    produces("application/json")

    parameters do
      search(:body, Schema.ref(:DataStructureSearchRequest), "Search query parameter")
    end

    response(200, "OK")
    response(403, "User is not authorized to perform this action")
    response(422, "Error while CSV download")
  end

  def csv(conn, params) do
    header_labels = Map.get(params, "header_labels", %{})
    params = Map.drop(params, ["header_labels", "page", "size"])

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
        |> send_resp(:ok, Download.to_csv(data_structures, header_labels))
    end
  end

  defp do_index(conn, search_params, page \\ 0, size \\ 50) do
    user = conn.assigns[:current_user]
    permission = conn.assigns[:search_permission]

    page = Map.get(search_params, "page", page)
    size = Map.get(search_params, "size", size)

    search_all =
      search_params
      |> Map.get("filters", %{})
      |> Map.get("all")

    scroll =
      case search_all do
        true -> "1m"
        _ -> nil
      end

    search_params
    |> deleted_structures()
    |> Map.drop(["page", "size"])
    |> Search.search_data_structures(user, permission, page, size, scroll)
  end

  defp deleted_structures(%{"filters" => %{"all" => true}} = search_params) do
    filters = Map.delete(Map.get(search_params, "filters", %{}), "all")
    Map.put(search_params, "filters", filters)
  end

  defp deleted_structures(search_params) do
    filters = Map.delete(Map.get(search_params, "filters", %{}), "all")
    search_params
    |> Map.put("filters", filters)
    |> Map.put(:without, ["deleted_at"])
  end
end
