defmodule TdDqWeb.ExecutionGroupController do
  use TdDqWeb, :controller

  alias TdDq.Executions
  alias TdDq.Executions.Group
  alias TdDq.Implementations.Search
  alias Truedat.Auth.Claims

  action_fallback(TdDqWeb.FallbackController)

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Executions, :list_groups, claims),
         groups <- Executions.list_groups() do
      render(conn, "index.json", execution_groups: groups)
    end
  end

  def show(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Executions, :get_group, claims),
         %Group{} = group <-
           Executions.get_group(params,
             preload: [executions: [:implementation, :rule, :result, :quality_events]]
           ) do
      render(conn, "show.json", execution_group: group)
    end
  end

  def create(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Executions, :create_group, claims, Group),
         %{} = creation_params <- creation_params(claims, params),
         {:ok, %{group: %{id: id}}} <- Executions.create_group(creation_params),
         %Group{} = group <-
           Executions.get_group(%{"id" => id},
             preload: [executions: [:implementation, :rule, :result]]
           ) do
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
