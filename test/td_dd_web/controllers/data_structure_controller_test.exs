defmodule TdDdWeb.DataStructureControllerTest do
  use TdDdWeb.ConnCase
  import TdDdWeb.Authentication, only: :functions
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.PathCache
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Lineage.GraphData
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService

  @create_attrs %{
    description: "some description",
    external_id: "some external_id",
    class: "some class",
    group: "some group",
    last_change_by: 42,
    name: "some name",
    type: "csv",
    ou: "GM",
    metadata: %{},
    system_id: 1
  }
  @update_attrs %{
    description: "some updated description",
    group: "some updated group",
    last_change_by: 43,
    name: "some updated name",
    type: "table",
    ou: "EM"
  }
  @invalid_attrs %{
    description: nil,
    group: nil,
    last_change_by: nil,
    name: nil,
    system: nil,
    type: nil,
    ou: nil
  }
  @default_template_attrs %{
    id: 0,
    label: "some label",
    name: "some template name",
    scope: "dd",
    content: [
      %{
        "name" => "group",
        "fields" => [
          %{
            "name" => "field",
            "type" => "string",
            "cardinality" => "1",
            "values" => %{"fixed" => ["1", "2"]}
          }
        ]
      }
    ]
  }

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockTdAuditService)
    start_supervised(MockPermissionResolver)
    start_supervised(PathCache)
    start_supervised(GraphData)
    :ok
  end

  setup %{conn: conn} do
    system = insert(:system, id: 1)
    {:ok, conn: put_req_header(conn, "accept", "application/json"), system: system}
  end

  @admin_user_name "app-admin"

  describe "show" do
    setup [:create_structure_hierarchy]

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with children", %{
      conn: conn,
      structure: %DataStructure{id: child_id}
    } do
      conn = get(conn, Routes.data_structure_data_structure_version_path(conn, :show, child_id, "latest"))
      %{"children" => children} = json_response(conn, 200)["data"]
      assert Enum.count(children) == 2
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with parents", %{
      conn: conn,
      structure: %DataStructure{id: child_id}
    } do
      conn = get(conn, Routes.data_structure_data_structure_version_path(conn, :show, child_id, "latest"))
      %{"parents" => parents} = json_response(conn, 200)["data"]
      assert Enum.count(parents) == 1
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with siblings", %{
      conn: conn,
      child_structures: [%DataStructure{id: id} | _]
    } do
      conn = get(conn, Routes.data_structure_data_structure_version_path(conn, :show, id, "latest"))
      %{"siblings" => siblings} = json_response(conn, 200)["data"]
      assert Enum.count(siblings) == 2
    end
  end

  describe "show data_structure with deletions in its hierarchy" do
    setup [:create_structure_hierarchy_with_logic_deletions]

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with children including deleted", %{
      conn: conn,
      parent_structure: %DataStructure{id: parent_id}
    } do
      conn = get(conn, Routes.data_structure_data_structure_version_path(conn, :show, parent_id, "latest"))
      %{"children" => children} = json_response(conn, 200)["data"]
      assert Enum.count(children) == 3
      assert [deleted_child] = Enum.filter(children, & &1["deleted_at"])
      assert deleted_child["name"] == "Child_deleted"
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with logic deleted parents", %{
      conn: conn,
      child_structures: [%DataStructure{id: child_id} | _]
    } do
      conn = get(conn, Routes.data_structure_data_structure_version_path(conn, :show, child_id, "latest"))
      assert %{"parents" => [parent]} = json_response(conn, 200)["data"]
      assert parent["name"] != "Parent_deleted"
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with logic deleted siblings", %{
      conn: conn,
      child_structures: [%DataStructure{id: id} | _]
    } do
      conn = get(conn, Routes.data_structure_data_structure_version_path(conn, :show, id, "latest"))
      %{"siblings" => siblings} = json_response(conn, 200)["data"]
      assert Enum.count(siblings) == 2
      assert Enum.find(siblings, [], &(Map.get(&1, "name") == "Child_deleted" == []))
    end
  end

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "lists all data_structures", %{conn: conn} do
      conn = get(conn, Routes.data_structure_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end

    @tag authenticated_user: @admin_user_name
    test "search all data_structures", %{conn: conn} do
      conn = post(conn, Routes.data_structure_path(conn, :create), data_structure: @create_attrs)
      data_structure = conn.assigns.data_structure
      [dsv | _] = data_structure.versions
      search_params = %{ou: " one§ tow §  #{data_structure.ou}"}

      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.data_structure_path(conn, :index, search_params))
      json_response = json_response(conn, 200)["data"]
      assert length(json_response) == 1
      json_response = Enum.at(json_response, 0)
      assert json_response["name"] == dsv.name
    end
  end

  describe "search" do
    setup [:create_data_structure]

    @tag :admin_authenticated
    test "search_all", %{conn: conn, data_structure: %DataStructure{id: id}} do
      conn = post(conn, Routes.data_structure_path(conn, :search), %{})

      assert json = json_response(conn, 200)
      assert [item] = json["data"]
      assert filters = json["filters"]

      assert Map.get(item, "id") == id
    end

    @tag :admin_authenticated
    test "search with query performs ngram search on name", %{conn: conn} do
      %{data_structure_id: id} =
        insert(:data_structure_version,
          name: "foobarbaz",
          data_structure: build(:data_structure, external_id: "foobarbaz")
        )

      conn = post(conn, Routes.data_structure_path(conn, :search), %{"query" => "obar"})

      assert json = json_response(conn, 200)
      assert [item] = json["data"]
      assert filters = json["filters"]

      assert Map.get(item, "id") == id
    end
  end

  describe "create data_structure" do
    @tag authenticated_user: @admin_user_name
    test "renders data_structure when data is valid", %{
      conn: conn,
      swagger_schema: schema,
      system: system
    } do
      conn = post(conn, Routes.data_structure_path(conn, :create), data_structure: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]
      validate_resp_schema(conn, schema, "DataStructureResponse")

      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.data_structure_data_structure_version_path(conn, :show, id, "latest"))
      json_response_data = conn |> json_response(200) |> Map.get("data")

      validate_resp_schema(conn, schema, "DataStructureVersionResponse")
      assert json_response_data["data_structure"]["id"] == id
      assert json_response_data["description"] == "some description"
      assert json_response_data["data_structure"]["external_id"] == "some external_id"
      assert json_response_data["class"] == "some class"
      assert json_response_data["type"] == "csv"
      assert json_response_data["data_structure"]["ou"] == "GM"
      assert json_response_data["group"] == "some group"
      assert json_response_data["name"] == "some name"
      assert json_response_data["system"]["id"] == system.id
      assert json_response_data["system"]["name"] == system.name
      assert json_response_data["data_structure"]["inserted_at"]
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.data_structure_path(conn, :create), data_structure: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update data_structure" do
    setup [:create_data_structure]

    @tag authenticated_user: @admin_user_name
    test "renders data_structure when data is valid", %{
      conn: conn,
      data_structure: %DataStructure{id: id} = data_structure,
      swagger_schema: schema
    } do
      conn =
        put(
          conn,
          Routes.data_structure_path(conn, :update, data_structure),
          data_structure: @update_attrs
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.data_structure_data_structure_version_path(conn, :show, id, "latest"))
      json_response_data = json_response(conn, 200)["data"]

      validate_resp_schema(conn, schema, "DataStructureVersionResponse")
      assert json_response_data["data_structure"]["id"] == id
      assert json_response_data["description"] == "some description"
      assert json_response_data["data_structure"]["inserted_at"]
    end

    @tag authenticated_user: @admin_user_name
    test "renders error when df_content is invalid", %{
      conn: conn,
      data_structure: data_structure
    } do
      conn =
        put(
          conn,
          Routes.data_structure_path(conn, :update, data_structure),
          data_structure: %{
            df_content: %{}
          }
        )

      assert response(conn, 422)
    end

    @tag authenticated_user: @admin_user_name
    test "renders data_structure when df_content is valid", %{
      conn: conn,
      data_structure: %{id: id} = data_structure
    } do
      df_content = %{"field" => "1"}

      conn =
        put(
          conn,
          Routes.data_structure_path(conn, :update, data_structure),
          data_structure: %{
            df_content: df_content
          }
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)
      conn = get(conn, Routes.data_structure_data_structure_version_path(conn, :show, id, "latest"))
      json_response_data = json_response(conn, 200)["data"]

      assert json_response_data["data_structure"]["df_content"] == df_content
    end
  end

  describe "delete data_structure" do
    setup [:create_data_structure]

    @tag authenticated_user: @admin_user_name
    test "deletes chosen data_structure", %{
      conn: conn,
      data_structure: data_structure,
      swagger_schema: schema
    } do
      conn = delete(conn, Routes.data_structure_path(conn, :delete, data_structure))
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent(404, fn ->
        conn = get(conn, Routes.data_structure_data_structure_version_path(conn, :show, data_structure.id, "latest"))
        validate_resp_schema(conn, schema, "DataStructureResponse")
      end)
    end
  end

  describe "data_structure confidentiality" do
    setup [:create_data_structure]

    @tag authenticated_user: @admin_user_name
    test "updates data_structure confidentiality", %{
      conn: conn,
      data_structure: %DataStructure{id: id} = data_structure
    } do
      assert Map.get(data_structure, :confidential) == false

      conn =
        put(
          conn,
          Routes.data_structure_path(conn, :update, data_structure),
          data_structure: %{confidential: true}
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.data_structure_data_structure_version_path(conn, :show, id, "latest"))
      json_response_data = json_response(conn, 200)["data"]

      assert json_response_data["data_structure"]["id"] == id
      assert json_response_data["data_structure"]["confidential"] == true
    end

    @tag authenticated_no_admin_user: "user"
    test "user with permission can update confidential data_structure", %{
      conn: conn,
      user: %{id: user_id}
    } do
      role_name = "confidential_editor"
      confidential = true
      data_structure = create_data_structure_and_permissions(user_id, role_name, confidential)
      %{id: id} = data_structure

      conn =
        put(
          conn,
          Routes.data_structure_path(conn, :update, data_structure),
          data_structure: %{df_content: %{"field" => "2"}}
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.data_structure_data_structure_version_path(conn, :show, id, "latest"))
      json_response_data = json_response(conn, 200)["data"]

      assert json_response_data["data_structure"]["id"] == id
      assert json_response_data["data_structure"]["df_content"] == %{"field" => "2"}
    end

    @tag authenticated_no_admin_user: "user_without_permission"
    test "user without confidential permission cannot update confidential data_structure", %{
      conn: conn,
      user: %{id: user_id}
    } do
      role_name = "editor"
      confidential = true
      data_structure = create_data_structure_and_permissions(user_id, role_name, confidential)
      %{id: id} = data_structure

      conn =
        put(
          conn,
          Routes.data_structure_path(conn, :update, data_structure),
          data_structure: %{df_content: %{foo: "bar"}}
        )

      assert json_response(conn, 403)
      new_data_structure = DataStructures.get_data_structure!(id)
      assert Map.get(new_data_structure, :df_content) == nil
    end

    @tag authenticated_no_admin_user: "user_without_confidential"
    test "user without confidential permission cannot update confidentiality of data_structure",
         %{conn: conn, user: %{id: user_id}} do
      role_name = "editor"
      confidential = false
      data_structure = create_data_structure_and_permissions(user_id, role_name, confidential)
      %{id: id} = data_structure

      conn =
        put(
          conn,
          Routes.data_structure_path(conn, :update, data_structure),
          data_structure: %{confidential: true}
        )

      assert json_response(conn, 200)
      new_data_structure = DataStructures.get_data_structure!(id)
      assert Map.get(new_data_structure, :confidential) == false
    end
  end

  defp create_data_structure(_) do
    template_name = "template_name"
    create_template(%{name: template_name})
    data_structure = insert(:data_structure, df_content: %{"field" => "1"})

    data_structure_version =
      insert(:data_structure_version, data_structure_id: data_structure.id, type: template_name)

    {:ok, data_structure: data_structure, data_structure_version: data_structure_version}
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

    default_relation_type_id = RelationTypes.get_default_relation_type().id

    insert(:data_structure_relation, parent_id: parent_version.id, child_id: structure_version.id, relation_type_id: default_relation_type_id)

    child_versions
    |> Enum.each(
      &insert(:data_structure_relation, parent_id: structure_version.id, child_id: &1.id, relation_type_id: default_relation_type_id)
    )

    {:ok,
     parent_structure: parent_structure, structure: structure, child_structures: child_structures}
  end

  defp create_structure_hierarchy_with_logic_deletions(_) do
    deleted_at = "2019-06-14 11:00:00Z"
    parent = insert(:data_structure, external_id: "Parent")
    parent_deleted = insert(:data_structure, external_id: "Parent_deleted")

    children = [
      insert(:data_structure, external_id: "Child1"),
      insert(:data_structure, external_id: "Child2"),
      insert(:data_structure, external_id: "Child_deleted")
    ]

    parent_version =
      insert(:data_structure_version,
        data_structure_id: parent.id,
        name: parent.external_id,
        deleted_at: deleted_at
      )

    parent_version_deleted = insert(:data_structure_version, data_structure_id: parent_deleted.id)

    child_versions =
      children
      |> Enum.map(
        &insert(:data_structure_version,
          data_structure_id: &1.id,
          name: &1.external_id,
          deleted_at: if(&1.external_id == "Child_deleted", do: deleted_at, else: nil)
        )
      )

    default_relation_type_id = RelationTypes.get_default_relation_type().id

    child_versions
    |> Enum.each(&insert(:data_structure_relation, parent_id: parent_version.id, child_id: &1.id, relation_type_id: default_relation_type_id))

    child_versions
    |> Enum.each(
      &insert(:data_structure_relation,
        parent_id: parent_version_deleted.id,
        child_id: &1.id,
        relation_type_id: default_relation_type_id
      )
    )

    {:ok, parent_structure: parent, child_structures: children}
  end

  defp create_data_structure_and_permissions(user_id, role_name, confidential) do
    domain_name = "domain_name"
    domain_id = 1
    TaxonomyCache.put_domain(%{name: domain_name, id: domain_id})

    MockPermissionResolver.create_acl_entry(%{
      principal_id: user_id,
      principal_type: "user",
      resource_id: domain_id,
      resource_type: "domain",
      role_name: role_name
    })

    template_name = "template_name"

    create_template(%{name: template_name})

    data_structure =
      insert(:data_structure, confidential: confidential, ou: domain_name, domain_id: domain_id)

    insert(:data_structure_version,
      data_structure_id: data_structure.id,
      name: data_structure.external_id,
      type: template_name
    )

    data_structure
  end

  def create_template(attrs \\ %{}) do
    attrs
    |> Enum.into(@default_template_attrs)
    |> Map.put(:updated_at, DateTime.utc_now())
    |> TemplateCache.put()

    :ok
  end
end
