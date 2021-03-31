defmodule TdDdWeb.ExecutionGroupControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.TaxonomyCache

  @moduletag sandbox: :shared

  setup_all do
    %{id: domain_id} = domain = build(:domain)
    TaxonomyCache.put_domain(domain)
    on_exit(fn -> TaxonomyCache.delete_domain(domain_id) end)

    [domain: domain]
  end

  setup tags do
    domain_id =
      case tags do
        %{domain: %{id: id}} -> id
        _ -> nil
      end

    groups =
      1..5
      |> Enum.map(fn _ ->
        insert(:execution,
          group: build(:execution_group),
          data_structure: build(:data_structure, domain_id: domain_id)
        )
      end)
      |> Enum.map(fn %{group: group} = execution ->
        Map.put(group, :executions, [execution])
      end)

    case tags do
      %{permissions: permissions, claims: %{user_id: user_id}, domain: %{id: domain_id}} ->
        create_acl_entry(user_id, "domain", domain_id, permissions)

      _ ->
        :ok
    end

    [groups: groups]
  end

  describe "GET /api/data_structures/execution_groups" do
    @tag authentication: [user_name: "not_an_admin"]
    @tag permissions: [:view_data_structures_profile]
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

    @tag authentication: [user_name: "not_an_admin"]
    test "returns forbidden if user doesn't have view permission", %{conn: conn} do
      assert %{"errors" => _} =
               conn
               |> get(Routes.execution_group_path(conn, :index))
               |> json_response(:forbidden)
    end
  end

  describe "GET /api/data_structures/execution_groups/:id" do
    @tag authentication: [user_name: "not_an_admin"]
    @tag permissions: [:view_data_structure, :view_data_structures_profile]
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

      assert %{"_embedded" => %{"data_structure" => %{"id" => _, "external_id" => _}}} = execution
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "returns forbidden if user doesn't have view permission", %{conn: conn} do
      assert %{"errors" => _} =
               conn
               |> get(Routes.execution_group_path(conn, :show, 123))
               |> json_response(:forbidden)
    end
  end

  describe "POST /api/data_structures/execution_groups" do
    @tag authentication: [user_name: "not_an_admin"]
    @tag permissions: [:profile_structures, :view_data_structures_profile]
    test "returns an OK response with the created execution group", %{
      conn: conn,
      swagger_schema: schema
    } do
      %{id: id1} = insert(:data_structure)
      %{id: id2} = insert(:data_structure)

      params = %{"data_structure_ids" => [id1, id2]}

      assert %{"data" => data} =
               conn
               |> post(Routes.execution_group_path(conn, :create, params))
               |> validate_resp_schema(schema, "ExecutionGroupResponse")
               |> json_response(:created)

      assert %{"id" => _, "inserted_at" => _} = data
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "returns forbidden if user doesn't have execute permission", %{conn: conn} do
      %{id: id} = insert(:data_structure)

      params = %{"data_structure_ids" => [id]}

      assert %{"errors" => _} =
               conn
               |> post(Routes.execution_group_path(conn, :index, params))
               |> json_response(:forbidden)
    end
  end

  defp create_acl_entry(user_id, resource_type, resource_id, permissions) do
    MockPermissionResolver.create_acl_entry(%{
      principal_id: user_id,
      principal_type: "user",
      resource_id: resource_id,
      resource_type: resource_type,
      permissions: permissions
    })
  end
end
