defmodule TdDdWeb.ProfileExecutionGroupController do
  use PhoenixSwagger
  use TdDdWeb, :controller

  alias TdDd.Executions
  alias TdDd.Executions.ProfileGroup
  alias TdDdWeb.SwaggerDefinitions
  alias Truedat.Auth.Claims

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.profile_execution_group_swagger_definitions()
  end

  swagger_path :index do
    description("List Execution Groups")
    response(200, "OK", Schema.ref(:ProfileExecutionGroupsResponse))
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(TdDd.Profiles, :search, claims),
         groups <- Executions.list_profile_groups() do
      render(conn, "index.json", profile_execution_groups: groups)
    end
  end

  swagger_path :show do
    description("Show Execution Group")
    response(200, "OK", Schema.ref(:ProfileExecutionGroupResponse))
    response(400, "Client Error")
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

  swagger_path :create do
    description("Create Execution Group")
    response(201, "Created", Schema.ref(:ProfileExecutionGroupResponse))
    response(400, "Client Error")
  end

  def create(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(TdDd.Profiles, :create, claims),
         %{} = creation_params <- creation_params(claims, params),
         {:ok, %{profile_group: %{id: id}}} <- Executions.create_profile_group(creation_params),
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

  defp creation_params(_claims, %{} = params), do: params
end
