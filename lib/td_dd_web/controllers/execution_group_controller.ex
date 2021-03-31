defmodule TdDdWeb.ExecutionGroupController do
  use PhoenixSwagger
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.Auth.Claims
  alias TdDd.Executions
  alias TdDd.Executions.Group
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.execution_group_swagger_definitions()
  end

  swagger_path :index do
    description("List Execution Groups")
    response(200, "OK", Schema.ref(:ExecutionGroupsResponse))
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, list(Group))},
         groups <- Executions.list_groups() do
      render(conn, "index.json", execution_groups: groups)
    end
  end

  swagger_path :show do
    description("Show Execution Group")
    response(200, "OK", Schema.ref(:ExecutionGroupResponse))
    response(400, "Client Error")
  end

  def show(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, show(Group))},
         %Group{} = group <-
           Executions.get_group(params, preload: [executions: [:data_structure, :profile]]) do
      executions =
        group
        |> Map.get(:executions)
        |> Enum.filter(&can?(claims, show(&1)))

      group = Map.put(group, :executions, executions)
      render(conn, "show.json", execution_group: group)
    end
  end

  swagger_path :create do
    description("Create Execution Group")
    response(201, "Created", Schema.ref(:ExecutionGroupResponse))
    response(400, "Client Error")
  end

  def create(conn, %{} = params) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]

    with {:can, true} <- {:can, can?(claims, create(Group))},
         %{} = creation_params <- creation_params(claims, params, permission),
         {:ok, %{group: %{id: id}}} <- Executions.create_group(creation_params),
         %Group{} = group <-
           Executions.get_group(%{"id" => id},
             preload: [executions: [:data_structure, :profile]]
           ) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.execution_group_path(conn, :show, group))
      |> render("show.json", execution_group: group)
    end
  end

  defp creation_params(
         %Claims{user_id: user_id},
         %{"data_structure_ids" => data_structure_ids} = params,
         _permission
       ) do
    execution_params = Enum.map(data_structure_ids, &%{"data_structure_id" => &1})

    params
    |> Map.delete("data_structure_ids")
    |> Map.put("executions", execution_params)
    |> Map.put("created_by_id", user_id)
  end

  defp creation_params(_claims, %{} = params, _permission), do: params
end
