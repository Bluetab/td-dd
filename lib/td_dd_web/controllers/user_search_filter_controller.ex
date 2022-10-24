defmodule TdDdWeb.UserSearchFilterController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.UserSearchFilters
  alias TdDd.UserSearchFilters.UserSearchFilter
  alias TdDdWeb.ErrorView
  alias TdDdWeb.SwaggerDefinitions

  action_fallback TdDdWeb.FallbackController

  def swagger_definitions do
    SwaggerDefinitions.user_search_filters_definitions()
  end

  swagger_path :index do
    description("Get all users concept search filters")
    produces("application/json")

    response(200, "OK", Schema.ref(:UserSearchFiltersResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def index(conn, params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(UserSearchFilters, :list, claims) do
      user_search_filters = UserSearchFilters.list_user_search_filters(params)
      render(conn, "index.json", user_search_filters: user_search_filters)
    end
  end

  swagger_path :index_by_user do
    description("Get authenticated user concept search filters")
    produces("application/json")

    response(200, "OK", Schema.ref(:UserSearchFiltersResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def index_by_user(conn, params) do
    claims = conn.assigns[:current_resource]

    user_search_filters = UserSearchFilters.list_user_search_filters(params, claims)
    render(conn, "index.json", user_search_filters: user_search_filters)
  end

  swagger_path :create do
    description("Creates concept user search filters")
    produces("application/json")

    parameters do
      user_search_filter(
        :body,
        Schema.ref(:CreateUserSearchFilter),
        "Parameters used to create a user search filter"
      )
    end

    response(200, "OK", Schema.ref(:UserSearchFilterResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def create(conn, %{"user_search_filter" => user_search_filter_params}) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]

    create_params = Map.put(user_search_filter_params, "user_id", user_id)

    with :ok <- Bodyguard.permit(UserSearchFilters, :create, claims, create_params),
         {:ok, %UserSearchFilter{} = user_search_filter} <-
           UserSearchFilters.create_user_search_filter(create_params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.user_search_filter_path(conn, :show, user_search_filter)
      )
      |> render("show.json", user_search_filter: user_search_filter)
    end
  end

  swagger_path :show do
    description("Get user search filter with the given id")
    produces("application/json")

    parameters do
      id(:path, :string, "id of User search filter", required: true)
    end

    response(200, "OK", Schema.ref(:UserSearchFilterResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    user_search_filter = UserSearchFilters.get_user_search_filter!(id)
    render(conn, "show.json", user_search_filter: user_search_filter)
  rescue
    _e in Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> put_view(ErrorView)
      |> render("404.json")
  end

  swagger_path :delete do
    description("Deletes a User search filter")

    parameters do
      id(:path, :string, "User search filter id", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]
    user_search_filter = UserSearchFilters.get_user_search_filter!(id)

    with :ok <-
           Bodyguard.permit(UserSearchFilters, :delete, claims, %{
             user_id: user_search_filter.user_id
           }),
         {:ok, %UserSearchFilter{}} <-
           UserSearchFilters.delete_user_search_filter(user_search_filter) do
      send_resp(conn, :no_content, "")
    else
      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")
    end
  rescue
    _e in Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> put_view(ErrorView)
      |> render("404.json")
  end
end
