defmodule TdDdWeb.DataStructureVersionControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.StructureTypeCache
  alias TdCache.TemplateCache
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Lineage.GraphData
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuthService

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    start_supervised(GraphData)
    :ok
  end

  setup %{conn: conn} do
    insert(:system, id: 1)
    {:ok, conn: put_req_header(conn, "accept", "application/json")}

    type = "Table"
    template_id = "999"

    {:ok, _} =
      TemplateCache.put(%{
        name: type,
        content: [
          %{
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
          }
        ],
        scope: "test",
        label: "template_label",
        id: template_id,
        updated_at: DateTime.utc_now()
      })

    %{id: structure_type_id} =
      structure_type =
      insert(:data_structure_type, template_id: template_id, structure_type: type)

    {:ok, _} = StructureTypeCache.put(structure_type)

    on_exit(fn ->
      TemplateCache.delete(template_id)
      StructureTypeCache.delete(structure_type_id)
    end)
  end

  @admin_user_name "app-admin"

  describe "show" do
    setup [:create_structure_hierarchy]

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with children", %{
      conn: conn,
      structure: %DataStructure{id: id}
    } do
      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_data_structure_version_path(conn, :show, id, 0))
               |> json_response(:ok)

      assert %{"children" => children} = data
      assert [_, _] = children
      assert Enum.all?(children, &(Map.get(&1, "order") == 1))
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with parents", %{
      conn: conn,
      structure: %DataStructure{id: id}
    } do
      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_data_structure_version_path(conn, :show, id, 0))
               |> json_response(:ok)

      assert %{"parents" => [_parent]} = data
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with siblings", %{
      conn: conn,
      child_structures: [%DataStructure{id: id} | _]
    } do
      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_data_structure_version_path(conn, :show, id, 0))
               |> json_response(:ok)

      assert %{"siblings" => [_, _]} = data
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with metadata", %{
      conn: conn,
      structure: %DataStructure{id: id}
    } do
      assert %{"data" => %{"metadata" => metadata}} =
               conn
               |> get(Routes.data_structure_data_structure_version_path(conn, :show, id, 0))
               |> json_response(:ok)

      assert %{"foo" => "bar"} = metadata
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure by data_structure_version_id", %{
      conn: conn,
      structure_version: %DataStructureVersion{id: id}
    } do
      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_version_path(conn, :show, id))
               |> json_response(:ok)

      assert %{"id" => ^id} = data
    end
  end

  describe "bulk_update" do
    @tag :admin_authenticated
    test "bulk update of data structures", %{conn: conn} do
      %{id: structure_id} =
        insert(:data_structure,
          external_id: "Structure",
          df_content: %{"Field1" => "foo", "Field2" => "bar"}
        )

      insert(:data_structure_version, data_structure_id: structure_id)

      assert %{"data" => data} =
               conn
               |> post(Routes.data_structure_path(conn, :bulk_update), %{
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
               |> json_response(:ok)

      assert %{"message" => [^structure_id | _]} = data
    end

    @tag :admin_authenticated
    test "bulk update of data structures with no filter type", %{conn: conn} do
      %{id: structure_id} = insert(:data_structure, external_id: "Structure")
      insert(:data_structure_version, data_structure_id: structure_id)

      assert %{"data" => data} =
               conn
               |> post(Routes.data_structure_path(conn, :bulk_update), %{
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
               |> json_response(:ok)

      assert %{"message" => []} = data
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

    structure_version =
      insert(:data_structure_version, data_structure_id: structure.id, metadata: %{foo: "bar"})

    child_versions =
      Enum.map(
        child_structures,
        &insert(:data_structure_version, data_structure_id: &1.id, metadata: %{"order" => 1})
      )

    %{id: relation_type_id} = RelationTypes.get_default()

    insert(:data_structure_relation,
      parent_id: parent_version.id,
      child_id: structure_version.id,
      relation_type_id: relation_type_id
    )

    Enum.each(
      child_versions,
      &insert(:data_structure_relation,
        parent_id: structure_version.id,
        child_id: &1.id,
        relation_type_id: relation_type_id
      )
    )

    {:ok,
     parent_structure: parent_structure,
     structure_version: structure_version,
     structure: structure,
     child_structures: child_structures}
  end
end
