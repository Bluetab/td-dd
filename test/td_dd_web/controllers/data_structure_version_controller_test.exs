defmodule TdDdWeb.DataStructureVersionControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.DataStructures.DataStructure
  alias TdDd.MockTaxonomyCache
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService
  alias TdPerms.MockDynamicFormCache

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockTdAuditService)
    start_supervised(MockPermissionResolver)
    start_supervised(MockTaxonomyCache)
    start_supervised(MockDynamicFormCache)
    :ok
  end

  setup %{conn: conn} do
    insert(:system, id: 1)
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @admin_user_name "app-admin"

  describe "show" do
    setup [:create_structure_hierarchy]

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with children", %{
      conn: conn,
      structure: %DataStructure{id: child_id}
    } do
      conn =
        get(conn, Routes.data_structure_data_structure_version_path(conn, :show, child_id, 0))

      %{"children" => children} = json_response(conn, 200)["data"]
      assert Enum.count(children) == 2
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with parents", %{
      conn: conn,
      structure: %DataStructure{id: child_id}
    } do
      conn =
        get(conn, Routes.data_structure_data_structure_version_path(conn, :show, child_id, 0))

      %{"parents" => parents} = json_response(conn, 200)["data"]
      assert Enum.count(parents) == 1
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with siblings", %{
      conn: conn,
      child_structures: [%DataStructure{id: id} | _]
    } do
      conn = get(conn, Routes.data_structure_data_structure_version_path(conn, :show, id, 0))
      %{"siblings" => siblings} = json_response(conn, 200)["data"]
      assert Enum.count(siblings) == 2
    end
  end

  defp create_structure_hierarchy(_) do
    parent_structure = insert(:data_structure)
    structure = insert(:data_structure)
    child_structures = [insert(:data_structure), insert(:data_structure)]
    parent_version = insert(:data_structure_version, data_structure_id: parent_structure.id)
    structure_version = insert(:data_structure_version, data_structure_id: structure.id)

    child_versions =
      child_structures
      |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

    insert(:data_structure_relation, parent_id: parent_version.id, child_id: structure_version.id)

    child_versions
    |> Enum.each(
      &insert(:data_structure_relation, parent_id: structure_version.id, child_id: &1.id)
    )

    {:ok,
     parent_structure: parent_structure, structure: structure, child_structures: child_structures}
  end
end
