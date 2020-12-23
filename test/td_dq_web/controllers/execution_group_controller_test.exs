defmodule TdDqWeb.ExecutionGroupControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  @moduletag sandbox: :shared
  @username "this_is_not_important"

  setup_all do
    start_supervised!(TdDq.Permissions.MockPermissionResolver)
    :ok
  end

  setup do
    groups =
      1..5
      |> Enum.map(fn _ ->
        insert(:execution, group: build(:execution_group), implementation: build(:implementation))
      end)
      |> Enum.map(fn %{group: group} = execution ->
        Map.put(group, :executions, [execution])
      end)

    [groups: groups]
  end

  describe "GET /api/execution_groups" do
    @tag authenticated_user: @username
    @tag role: "view"
    test "returns an OK response with the list of execution groups", %{
      conn: conn,
      swagger_schema: schema
    } do
      assert %{"data" => groups} =
               conn
               |> get(Routes.execution_group_path(conn, :index))
               |> validate_resp_schema(schema, "ExecutionGroupsResponse")
               |> json_response(:ok)

      assert length(groups) == 5
    end

    @tag authenticated_user: @username
    test "returns forbidden if user doesn't have view permission", %{conn: conn} do
      assert %{"errors" => _} =
               conn
               |> get(Routes.execution_group_path(conn, :index))
               |> json_response(:forbidden)
    end
  end

  describe "GET /api/execution_groups/:id" do
    @tag authenticated_user: @username
    @tag role: "view"
    test "returns an OK response with the execution group", %{
      conn: conn,
      swagger_schema: schema,
      groups: groups
    } do
      %{id: id} = Enum.random(groups)

      assert %{"data" => data} =
               conn
               |> get(Routes.execution_group_path(conn, :show, id))
               |> validate_resp_schema(schema, "ExecutionGroupResponse")
               |> json_response(:ok)

      assert %{"id" => ^id, "inserted_at" => _, "_embedded" => embedded} = data
      assert %{"executions" => [execution]} = embedded

      assert %{"_embedded" => %{"implementation" => %{"id" => _, "implementation_key" => _}}} =
               execution
    end

    @tag authenticated_user: @username
    test "returns forbidden if user doesn't have view permission", %{conn: conn} do
      assert %{"errors" => _} =
               conn
               |> get(Routes.execution_group_path(conn, :show, 123))
               |> json_response(:forbidden)
    end
  end

  describe "POST /api/execution_groups" do
    @tag :admin_authenticated
    test "returns an OK response with the created execution group", %{
      conn: conn,
      swagger_schema: schema
    } do
      %{id: id1} = insert(:implementation)
      %{id: id2} = insert(:implementation)

      filters = %{"id" => [id1, id2]}
      params = %{"filters" => filters}

      assert %{"data" => data} =
               conn
               |> post(Routes.execution_group_path(conn, :create, params))
               |> validate_resp_schema(schema, "ExecutionGroupResponse")
               |> json_response(:created)

      assert %{"id" => _, "inserted_at" => _} = data
    end

    @tag authenticated_user: @username
    test "returns forbidden if user doesn't have execute permission", %{conn: conn} do
      %{id: id} = insert(:implementation)

      params = %{"implementation_ids" => [id]}

      assert %{"errors" => _} =
               conn
               |> post(Routes.execution_group_path(conn, :index, params))
               |> json_response(:forbidden)
    end
  end
end
