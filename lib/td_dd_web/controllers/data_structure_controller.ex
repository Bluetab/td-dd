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
  alias TdPerms.DataFieldCache
  alias TdPerms.FieldLinkCache
  alias TdPerms.TaxonomyCache

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.data_structure_swagger_definitions()
  end

  swagger_path :index do
    get("/data_structures")
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

    data_structures =
      data_structures
      |> add_attrs_to_list_data_structures()

    render(conn, "index.json", data_structures: data_structures)
  end

  defp do_index(user, search_params \\ %{}, page \\ 0, size \\ 50) do
    page = search_params |> Map.get("page", page)
    size = search_params |> Map.get("size", size)

    search_params
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

  swagger_path :create do
    post("/data_structures")
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
      |> Map.put("last_change_at", DateTime.utc_now())
      |> Map.put("metadata", %{})
      |> DataStructures.add_domain_id(TaxonomyCache.get_domain_name_to_id_map())

    with true <- can?(user, create_data_structure(Map.fetch!(creation_params, "domain_id"))),
      {:ok, %DataStructure{} = data_structure} <-
           DataStructures.create_data_structure(creation_params) do

      AuditSupport.create_data_structure(conn, data_structure.id, data_structure_params)

      conn
      |> put_status(:created)
      |> put_resp_header("location", data_structure_path(conn, :show, data_structure))
      |> render("show.json", data_structure: data_structure)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422")
    end
  end

  swagger_path :show do
    get("/data_structures/{id}")
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

    data_structure =
      id
      |> DataStructures.get_data_structure_with_fields!
      |> DataStructures.with_latest_children
      |> add_fields_external_ids
      |> get_concepts_linked_to_fields()

    with true <- can?(user, view_data_structure(data_structure)) do
      user_permissions = %{
        update: can?(user, update_data_structure(data_structure))
      }

      render(conn, "show.json",
        data_structure: data_structure,
        user_permissions: user_permissions
      )
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422")
    end
  end

  defp add_fields_external_ids(data_structure) do
    data_structure
    |> Map.put(
      :data_fields,
      Enum.map(data_structure.data_fields, fn field ->
        external_id =
          DataFieldCache.get_external_id(data_structure.system,
                                         data_structure.group,
                                         data_structure.name, field.name)
        Map.put(field, :external_id, external_id)
      end)
    )
  end

  defp get_concepts_linked_to_fields(data_structure) do
    data_structure
    |> Map.put(
      :data_fields,
      Enum.map(data_structure.data_fields, fn field ->
        Map.put(field, :bc_related, FieldLinkCache.get_resources(field.id, "field"))
      end)
    )
  end

  swagger_path :update do
    patch("/data_structures/{id}")
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

    update_params =
      data_structure_params
      |> Map.put("last_change_by", get_current_user_id(conn))
      |> Map.put("last_change_at", DateTime.utc_now())
      |> DataStructures.add_domain_id(TaxonomyCache.get_domain_name_to_id_map())

    with true <- can?(user, update_data_structure(data_structure_old)),
        {:ok, %DataStructure{} = data_structure} <-
           DataStructures.update_data_structure(data_structure_old, update_params) do

      AuditSupport.update_data_structure(conn, data_structure_old, data_structure_params)

      data_structure = get_concepts_linked_to_fields(data_structure)

      render(conn, "show.json", data_structure: data_structure)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422")
    end
  end

  swagger_path :delete do
    delete("/data_structures/{id}")
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
        |> render(ErrorView, :"403")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422")
    end
  end

  defp get_current_user_id(conn) do
    GuardianPlug.current_resource(conn).id
  end

  swagger_path :search do
    post("/data_structures/search")
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

    %{results: data_structures, total: total} = do_index(user, params)

    data_structures =
      data_structures
      |> add_attrs_to_list_data_structures()

    conn
      |> put_resp_header("x-total-count", "#{total}")
      |> render("index.json", data_structures: data_structures)
  end

  defp add_attrs_to_list_data_structures(data_structures) do
    data_structures
        |> Enum.map(fn ds -> get_concepts_linked_to_fields(ds) end)
  end
end
