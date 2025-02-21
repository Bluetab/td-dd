defmodule TdDdWeb.ProfileExecutionGroupController do
  use TdDdWeb, :controller

  alias TdCore.Search
  alias TdDd.Executions
  alias TdDd.Executions.ProfileGroup

  alias Truedat.Auth.Claims

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(TdDd.Profiles, :search, claims),
         groups <- Executions.list_profile_groups() do
      render(conn, "index.json", profile_execution_groups: groups)
    end
  end

  def show(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(TdDd.Profiles, :search, claims),
         %ProfileGroup{} = group <-
           Executions.get_profile_group(params,
             preload: [executions: [:data_structure, :profile, :profile_events]],
             enrich: [:latest]
           ) do
      executions =
        group
        |> Map.get(:executions)
        |> Enum.filter(&Bodyguard.permit?(TdDd.Profiles, :view, claims, &1))

      group = Map.put(group, :executions, executions)
      render(conn, "show.json", profile_execution_group: group)
    end
  end

  def create(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    # If a parent ID for structure fields is specified, the profile should only be executed for fields that the user
    # was able to view.
    domain_ids = Search.Permissions.get_search_permissions(["view_data_structure"], claims)

    with :ok <- Bodyguard.permit(TdDd.Profiles, :create, claims),
         %{} = creation_params <- creation_params(claims, params),
         {:ok, %{profile_group: %{id: id}}} <-
           Executions.create_profile_group(creation_params, domain_ids: domain_ids),
         %ProfileGroup{} = group <-
           Executions.get_profile_group(%{"id" => id},
             preload: [executions: [:data_structure, :profile]],
             enrich: [:latest]
           ) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.profile_execution_group_path(conn, :show, group))
      |> render("show.json", profile_execution_group: group)
    end
  end

  defp creation_params(
         %Claims{user_id: user_id},
         %{"data_structure_ids" => data_structure_ids} = params
       ) do
    execution_params = Enum.map(data_structure_ids, &%{"data_structure_id" => &1})

    params
    |> Map.delete("data_structure_ids")
    |> Map.put("executions", execution_params)
    |> Map.put("created_by_id", user_id)
  end

  defp creation_params(%Claims{user_id: user_id}, %{"parent_structure_id" => parent_structure_id}),
    do: %{parent_structure_id: parent_structure_id, created_by_id: user_id}

  defp creation_params(_claims, %{} = params), do: params
end
