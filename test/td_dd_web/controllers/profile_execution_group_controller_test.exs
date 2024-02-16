defmodule TdDdWeb.ProfileExecutionGroupControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  @moduletag sandbox: :shared

  setup_all do
    [domain: CacheHelpers.insert_domain()]
  end

  setup tags do
    start_supervised!(TdDd.Search.StructureEnricher)

    domain_id =
      case tags do
        %{domain: %{id: id}} -> id
        _ -> nil
      end

    %{data_structure: data_structure} =
      insert(:data_structure_version,
        data_structure: insert(:data_structure, domain_ids: [domain_id])
      )

    groups =
      1..5
      |> Enum.map(fn _ ->
        insert(:profile_execution,
          profile_group: build(:profile_execution_group),
          data_structure: data_structure,
          profile: build(:profile)
        )
      end)
      |> Enum.map(fn %{profile_group: group} = execution ->
        Map.put(group, :executions, [execution])
      end)

    case tags do
      %{permissions: permissions, claims: claims, domain: %{id: domain_id}} ->
        CacheHelpers.put_session_permissions(claims, domain_id, permissions)

      _ ->
        :ok
    end

    [groups: groups]
  end

  describe "GET /api/profile_execution_groups" do
    @tag authentication: [user_name: "not_an_admin"]
    @tag permissions: [:view_data_structures_profile]
    test "returns an OK response with the list of execution groups", %{
      conn: conn,
      swagger_schema: schema
    } do
      assert %{"data" => groups} =
               conn
               |> get(Routes.profile_execution_group_path(conn, :index))
               |> validate_resp_schema(schema, "ProfileExecutionGroupsResponse")
               |> json_response(:ok)

      assert length(groups) == 5
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "returns forbidden if user doesn't have view permission", %{conn: conn} do
      assert %{"errors" => _} =
               conn
               |> get(Routes.profile_execution_group_path(conn, :index))
               |> json_response(:forbidden)
    end
  end

  describe "GET /api/profile_execution_groups/:id" do
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
               |> get(Routes.profile_execution_group_path(conn, :show, id))
               |> validate_resp_schema(schema, "ProfileExecutionGroupResponse")
               |> json_response(:ok)

      assert %{"id" => ^id, "inserted_at" => _, "_embedded" => embedded} = data
      assert %{"executions" => [execution]} = embedded

      assert %{"_embedded" => %{"data_structure" => %{"id" => _, "external_id" => _}}} = execution
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "returns forbidden if user doesn't have view permission", %{conn: conn} do
      assert %{"errors" => _} =
               conn
               |> get(Routes.profile_execution_group_path(conn, :show, 123))
               |> json_response(:forbidden)
    end
  end

  describe "POST /api/profile_execution_groups" do
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
               |> post(Routes.profile_execution_group_path(conn, :create, params))
               |> validate_resp_schema(schema, "ProfileExecutionGroupResponse")
               |> json_response(:created)

      assert %{"id" => _, "inserted_at" => _} = data
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "returns forbidden if user doesn't have execute permission", %{conn: conn} do
      %{id: id} = insert(:data_structure)

      params = %{"data_structure_ids" => [id]}

      assert %{"errors" => _} =
               conn
               |> post(Routes.profile_execution_group_path(conn, :index, params))
               |> json_response(:forbidden)
    end
  end
end
