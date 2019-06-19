defmodule TdDdWeb.DataStructureController do
  require Logger
  import Canada, only: [can?: 2]
  use TdDdWeb, :controller
  use PhoenixSwagger
  alias Ecto
  alias TdDd.Audit.AuditSupport
  alias TdDd.Auth.Guardian.Plug, as: GuardianPlug
  alias TdDd.DataStructure.Search
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDdWeb.ErrorView
  alias TdDdWeb.SwaggerDefinitions

  @taxonomy_cache Application.get_env(:td_dd, :taxonomy_cache)

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.data_structure_swagger_definitions()
  end

  swagger_path :index do
    description("List Data Structures")

    parameters do
      ou(:query, :string, "List of organizational units", required: false)
    end

    response(200, "OK", Schema.ref(:DataStructuresResponse))
  end

  def index(conn, params) do
    user = conn.assigns[:current_user]

    %{results: data_structures} =
      case getOUs(params) do
        [] -> do_index(user)
        in_params -> do_index(user, %{"filters" => %{"ou.raw" => in_params}}, 0, 10_000)
      end

    render(conn, "index.json", data_structures: data_structures)
  end

  defp do_index(user, search_params \\ %{}, page \\ 0, size \\ 50) do
    page = search_params |> Map.get("page", page)
    size = search_params |> Map.get("size", size)

    search_params
    |> logic_deleted_filter
    |> Map.drop(["page", "size"])
    |> Search.search_data_structures(user, page, size)
  end

  defp getOUs(params) do
    case Map.get(params, "ou", nil) do
      nil ->
        []

      value ->
        value
        |> String.split("§")
        |> Enum.map(&String.trim(&1))
    end
  end

  defp logic_deleted_filter(search_params) do
    case Map.has_key?(search_params, "filters") do
      true ->
        filters = search_params |> Map.get("filters") |> Map.put("status", "")
        Map.put(search_params, "filters", filters)
      false -> search_params |> Map.put("filters", %{"status" => ""})
    end
  end

  swagger_path :create do
    description("Creates Data Structure")
    produces("application/json")

    parameters do
      data_structure(:body, Schema.ref(:DataStructureCreate), "Data Structure create attrs")
    end

    response(201, "OK", Schema.ref(:DataStructureResponse))
    response(400, "Client Error")
    response(403, "Unauthorized")
    response(422, "Unprocessable Entity")
  end

  def create(conn, %{"data_structure" => data_structure_params}) do
    user = conn.assigns[:current_user]

    creation_params =
      data_structure_params
      |> Map.put("last_change_by", get_current_user_id(conn))
      |> Map.put("last_change_at", DateTime.truncate(DateTime.utc_now(), :second))
      |> Map.put("metadata", %{})
      |> DataStructures.add_domain_id(@taxonomy_cache.get_domain_name_to_id_map())

    with true <- can?(user, create_data_structure(Map.fetch!(creation_params, "domain_id"))),
         {:ok, %DataStructure{id: id}} <- DataStructures.create_data_structure(creation_params) do
      AuditSupport.create_data_structure(conn, id, data_structure_params)

      data_structure =
        id
        |> get_data_structure

      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.data_structure_path(conn, :show, data_structure))
      |> render("show.json", data_structure: data_structure)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :show do
    description("Show Data Structure")
    produces("application/json")

    parameters do
      id(:path, :integer, "Data Structure ID", required: true)
    end

    response(200, "OK", Schema.ref(:DataStructureResponse))
    response(400, "Client Error")
    response(403, "Unauthorized")
    response(422, "Unprocessable Entity")
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns[:current_user]

    data_structure = id |> get_data_structure()

    with true <- can?(user, view_data_structure(data_structure)) do
      user_permissions = %{
        update: can?(user, update_data_structure(data_structure)),
        confidential: can?(user, manage_confidential_structures(data_structure)),
        view_profiling_permission: can?(user, view_data_structures_profile(data_structure))
      }

      render(
        conn,
        "show.json",
        data_structure: data_structure,
        user_permissions: user_permissions
      )
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  defp get_data_structure(id) do
    id
    |> DataStructures.get_data_structure_with_fields!([deleted: false])
    |> DataStructures.with_versions()
    |> DataStructures.with_latest_children([deleted: false])
    |> DataStructures.with_latest_parents([deleted: false])
    |> DataStructures.with_latest_siblings([deleted: false])
    |> DataStructures.with_latest_ancestry()
    |> DataStructures.with_field_external_ids()
    |> DataStructures.with_field_links()
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
    response(403, "Unauthorized")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{"id" => id, "data_structure" => data_structure_params}) do
    user = conn.assigns[:current_user]

    data_structure_old = DataStructures.get_data_structure_with_fields!(id)

    manage_confidential_structures =
      can?(user, manage_confidential_structures(data_structure_old))

    update_params =
      data_structure_params
      |> check_confidential_field(manage_confidential_structures)
      |> Map.put("last_change_by", get_current_user_id(conn))
      |> Map.put("last_change_at", DateTime.truncate(DateTime.utc_now(), :second))
      |> DataStructures.add_domain_id(@taxonomy_cache.get_domain_name_to_id_map())

    with true <- can?(user, update_data_structure(data_structure_old)),
         {:ok, %DataStructure{} = data_structure} <-
           DataStructures.update_data_structure(data_structure_old, update_params) do
      AuditSupport.update_data_structure(conn, data_structure_old, data_structure_params)

      data_structure = get_data_structure(data_structure.id)

      render(conn, "show.json", data_structure: data_structure)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
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
    response(403, "Unauthorized")
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
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
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
    user = conn.assigns[:current_user]

    %{results: data_structures, aggregations: aggregations, total: total} = do_index(user, params)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("index.json", data_structures: data_structures, filters: aggregations)
  end

  def get_system_structures(conn, params) do
    user = conn.assigns[:current_user]

    data_structures =
      params
      |> DataStructures.list_data_structures_with_no_parents([deleted: false])
      |> Enum.filter(&can?(user, view_data_structure(&1)))

    total = length(data_structures)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("index.json", data_structures: data_structures)
  end
end
