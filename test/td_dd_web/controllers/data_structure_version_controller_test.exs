defmodule TdDdWeb.DataStructureVersionControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.TemplateCache
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.PathCache
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockTdAuditService)
    start_supervised(MockPermissionResolver)
    start_supervised(PathCache)
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

    @tag authenticated_user: @admin_user_name
    test "renders a data structure by data_structure_version_id", %{
      conn: conn,
      structure_version: %DataStructureVersion{id: id}
    } do
      conn = get(conn, Routes.data_structure_version_path(conn, :show, id))

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
    end
  end

  describe "bulk_update" do
    @tag :admin_authenticated
    test "bulk update of data structures", %{conn: conn} do
      structure = insert(:data_structure, external_id: "Structure")
      _structure_version = insert(:data_structure_version, data_structure_id: structure.id)

      TemplateCache.put(%{
        name: "Table",
        content: [%{
          "name" => "group",
          "fields" => [
            %{
              "name" => "Field1",
              "type" => "string",
              "group" => "Multiple Group",
              "label" => "Multiple 1",
              "values" => nil,
              "cardinality" => "1"
            },
            %{
              "name" => "Field2",
              "type" => "string",
              "group" => "Multiple Group",
              "label" => "Multiple 1",
              "values" => nil,
              "cardinality" => "1"
            }
          ]
        }],
        scope: "test",
        label: "template_label",
        id: "999",
        updated_at: DateTime.utc_now()
      })

      conn =
        post(conn, Routes.data_structure_path(conn, :bulk_update), %{
          "bulk_update_request" => %{
            "update_attributes" => %{
              "df_content" => %{
                "Field1" => "hola soy field 1",
                "Field2" => "hola soy field 2"
              },
              "otra_cosa" => 2
            },
            "search_params" => %{
              "filters" => %{
                "type.raw" => [
                  "Table"
                ]
              }
            }
          }
        })

      %{"message" => updated_data_structures_ids} = json_response(conn, 200)["data"]
      assert Enum.at(updated_data_structures_ids, 0) == structure.id
    end

    @tag :admin_authenticated
    test "bulk update of data structures with no filter type", %{conn: conn} do
      structure = insert(:data_structure, external_id: "Structure")
      _structure_version = insert(:data_structure_version, data_structure_id: structure.id)

      conn =
        post(conn, Routes.data_structure_path(conn, :bulk_update), %{
          "bulk_update_request" => %{
            "update_attributes" => %{
              "df_content" => %{
                "Field1" => "hola soy field 1",
                "Field2" => "hola soy field 2"
              },
              "otra_cosa" => 2
            },
            "search_params" => %{
              "filters" => %{
                "type.raw" => [
                  "Field"
                ]
              }
            }
          }
        })

      %{"message" => updated_data_structures_ids} = json_response(conn, 200)["data"]
      assert Enum.at(updated_data_structures_ids, 0) == nil
    end
  end

  defp create_structure_hierarchy(_) do
    parent_structure = insert(:data_structure, external_id: "Parent")
    structure = insert(:data_structure, external_id: "Structure")

    child_structures = [
      insert(:data_structure, external_id: "Child1"),
      insert(:data_structure, external_id: "Child2")
    ]

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
     parent_structure: parent_structure,
     structure_version: structure_version,
     structure: structure,
     child_structures: child_structures}
  end
end
