defmodule TdDqWeb.ExecutionGroupController do
  use TdDqWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDq.Auth.Claims
  alias TdDq.Executions
  alias TdDq.Executions.Group
  alias TdDq.Rules.Implementations.Search

  action_fallback(TdDqWeb.FallbackController)

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
           Executions.get_group(params, preload: [executions: [:implementation, :rule, :result]]) do
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

    with {:can, true} <- {:can, can?(claims, create(Group))},
         %{} = creation_params <- creation_params(claims, params),
         {:ok, %{group: group}} <- Executions.create_group(creation_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.execution_group_path(conn, :show, group))
      |> render("show.json", execution_group: group)
    end
  end

  defp creation_params(%Claims{user_id: user_id} = claims, %{} = params) do
    execution_params =
      params
      |> Search.search_executable(claims)
      |> Enum.map(&Map.take(&1, [:id, :structure_aliases]))
      |> Enum.map(fn %{id: id} = params ->
        params |> Map.delete(:id) |> Map.put(:implementation_id, id)
      end)

    params
    |> Map.put("executions", execution_params)
    |> Map.put("created_by_id", user_id)
  end

  defp creation_params(
         %Claims{user_id: user_id},
         %{"implementation_ids" => implementation_id} = params
       ) do
    execution_params = Enum.map(implementation_id, &%{"implementation_id" => &1})

    params
    |> Map.delete("implementation_ids")
    |> Map.put("executions", execution_params)
    |> Map.put("created_by_id", user_id)
  end

  defp creation_params(_claims, %{} = params), do: params
end
