defmodule TdDdWeb.GrantController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.CSV.Download
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants
  alias TdDd.Grants.Grant
  alias TdDd.Grants.Search
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  @grant_actions [:manage_grant_removal, :manage_grant_removal_request, :update]

  def swagger_definitions do
    SwaggerDefinitions.grant_swagger_definitions()
  end

  swagger_path :index do
    description("Get grants")
    produces("application/json")

    response(200, "OK", Schema.ref(:GrantResponse))
    response(422, "Client Error")
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Grants, :query, claims),
         grants <- Grants.list_active_grants([]) do
      render(conn, "index.json", grants: grants)
    end
  end

  swagger_path :create do
    description("Creates a Grant")
    produces("application/json")

    parameters do
      data_structure_external_id(:path, :string, "Data Structure External Id", required: true)

      grant(
        :body,
        Schema.ref(:GrantCreate),
        "Grant create attrs"
      )
    end

    response(201, "OK", Schema.ref(:GrantResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def create(conn, %{"grant" => grant_params, "data_structure_id" => data_structure_external_id}) do
    with claims <- conn.assigns[:current_resource],
         {:data_structure, %DataStructure{} = data_structure} <-
           {:data_structure,
            DataStructures.get_data_structure_by_external_id(data_structure_external_id)},
         :ok <- Bodyguard.permit(DataStructures, :manage_grants, claims, data_structure),
         {:ok, %{grant: %{id: id}}} <- Grants.create_grant(grant_params, data_structure, claims),
         %Grant{} = grant <- Grants.get_grant!(id, preload: [:data_structure, :system]) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.grant_path(conn, :show, grant))
      |> render("show.json", grant: grant)
    else
      {:data_structure, nil} -> {:error, :not_found, "DataStructure"}
      error -> error
    end
  end

  swagger_path :show do
    description("Shows Grant")
    produces("application/json")

    parameters do
      id(:path, :string, "Grant Id", required: true)
    end

    response(200, "OK", Schema.ref(:GrantResponse))
    response(403, "Forbidden")
    response(404, "Not Found")
  end

  def show(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         %Grant{} = grant <-
           Grants.get_grant!(id, preload: [:data_structure, :data_structure_version, :system]),
         :ok <- Bodyguard.permit(Grants, :view, claims, grant) do
      actions =
        @grant_actions
        |> Grants.maybe_disable_actions(grant)
        |> Enum.filter(&Bodyguard.permit?(Grants, &1, claims, grant))
        |> Map.new(fn value -> {value, %{}} end)

      render(conn, "show.json", grant: grant, actions: actions)
    end
  end

  swagger_path :update do
    description("Updates Grant")
    produces("application/json")

    parameters do
      id(:path, :string, "Grant Id", required: true)

      grant(
        :body,
        Schema.ref(:GrantUpdate),
        "Grant update attrs"
      )
    end

    response(201, "OK", Schema.ref(:GrantResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{"id" => id, "action" => "mark_pending_removal"}) do
    with claims <- conn.assigns[:current_resource],
         %Grant{} = grant <- Grants.get_grant!(id, preload: :data_structure),
         :ok <- Bodyguard.permit(Grants, :manage_grant_removal, claims, grant),
         {:ok, %{grant: _}} <- Grants.update_grant(grant, %{pending_removal: true}, claims),
         %Grant{} = grant <- Grants.get_grant!(id, preload: [:data_structure, :system]) do
      render(conn, "show.json", grant: grant)
    end
  end

  def update(conn, %{"id" => id, "action" => "unmark_pending_removal"}) do
    with claims <- conn.assigns[:current_resource],
         %Grant{} = grant <- Grants.get_grant!(id, preload: :data_structure),
         :ok <- Bodyguard.permit(Grants, :manage_grant_removal, claims, grant),
         {:ok, %{grant: _}} <- Grants.update_grant(grant, %{pending_removal: false}, claims),
         %Grant{} = grant <- Grants.get_grant!(id, preload: [:data_structure, :system]) do
      render(conn, "show.json", grant: grant)
    end
  end

  def update(conn, %{"id" => id, "action" => "set_removed"}) do
    update_params = %{
      pending_removal: false,
      end_date: DateTime.utc_now()
    }

    with claims <- conn.assigns[:current_resource],
         %Grant{} = grant <- Grants.get_grant!(id, preload: :data_structure),
         :ok <- Bodyguard.permit(Grants, :manage, claims, grant),
         {:ok, %{grant: _}} <- Grants.update_grant(grant, update_params, claims),
         %Grant{} = grant <- Grants.get_grant!(id, preload: [:data_structure, :system]) do
      render(conn, "show.json", grant: grant)
    end
  end

  def update(conn, %{"id" => id, "grant" => grant_params}) do
    with claims <- conn.assigns[:current_resource],
         %Grant{} = grant <- Grants.get_grant!(id, preload: :data_structure),
         :ok <- Bodyguard.permit(Grants, :manage, claims, grant),
         {:ok, %{grant: _}} <- Grants.update_grant(grant, grant_params, claims),
         %Grant{} = grant <- Grants.get_grant!(id, preload: [:data_structure, :system]) do
      render(conn, "show.json", grant: grant)
    end
  end

  swagger_path :delete do
    description("Deletes a Grant")
    produces("application/json")

    parameters do
      id(:path, :integer, "Grant ID", required: true)
    end

    response(202, "Accepted")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def delete(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         %Grant{} = grant <- Grants.get_grant!(id, preload: [:data_structure, :system]),
         :ok <- Bodyguard.permit(Grants, :manage, claims, grant),
         {:ok, %{grant: %Grant{}}} <- Grants.delete_grant(grant, claims) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :csv do
    description("Download CSV of grants")
    produces("application/json")

    parameters do
      search(:body, Schema.ref(:GrantCSVRequest), "Search query parameter")
    end

    response(200, "OK")
    response(403, "User is not authorized to perform this action")
    response(422, "Error during CSV download")
  end

  def csv(conn, %{"search_by" => search_by, "header_labels" => header_labels} = params) do
    params = Map.drop(params, ["header_labels", "page", "size"])
    claims = conn.assigns[:current_resource]

    %{results: grants} =
      case search_by do
        "permissions" ->
          Search.search(params, claims, 0, 10_000)

        "user" ->
          Search.search_by_user(params, claims, 0, 10_000)
      end

    case grants do
      [] ->
        send_resp(conn, :no_content, "")

      _ ->
        conn
        |> put_resp_content_type("text/csv", "utf-8")
        |> put_resp_header("content-disposition", "attachment; filename=\"structures.zip\"")
        |> send_resp(:ok, Download.to_csv_grants(grants, header_labels))
    end
  end
end
