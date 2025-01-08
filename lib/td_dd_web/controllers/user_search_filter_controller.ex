defmodule TdDdWeb.UserSearchFilterController do
  use TdDdWeb, :controller

  alias TdDd.UserSearchFilters
  alias TdDd.UserSearchFilters.UserSearchFilter
  alias TdDdWeb.ErrorView

  action_fallback TdDdWeb.FallbackController

  def index(conn, params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(UserSearchFilters, :list, claims) do
      user_search_filters = UserSearchFilters.list_user_search_filters(params)
      render(conn, "index.json", user_search_filters: user_search_filters)
    end
  end

  def index_by_user(conn, params) do
    claims = conn.assigns[:current_resource]

    user_search_filters = UserSearchFilters.list_user_search_filters(params, claims)
    render(conn, "index.json", user_search_filters: user_search_filters)
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
