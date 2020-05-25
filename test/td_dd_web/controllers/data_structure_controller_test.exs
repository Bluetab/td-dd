defmodule TdDdWeb.DataStructureControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.PathCache
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Lineage.GraphData
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService

  import Routes

  @create_attrs %{
    description: "some description",
    external_id: "some external_id",
    class: "some class",
    group: "some group",
    last_change_by: 42,
    name: "some name",
    type: "csv",
    metadata: %{},
    system_id: 1
  }
  @update_attrs %{
    description: "some updated description",
    group: "some updated group",
    last_change_by: 43,
    name: "some updated name",
    type: "table"
  }
  @invalid_attrs %{
    description: nil,
    group: nil,
    last_change_by: nil,
    name: nil,
    system: nil,
    type: nil
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
    test "renders a data structure with children", %{conn: conn, structure: %{id: child_id}} do
      assert %{"data" => %{"children" => children}} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, child_id, "latest"))
               |> json_response(:ok)

      assert Enum.count(children) == 2
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with parents", %{conn: conn, structure: %{id: child_id}} do
      assert %{"data" => %{"parents" => parents}} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, child_id, "latest"))
               |> json_response(:ok)

      assert Enum.count(parents) == 1
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with siblings", %{
      conn: conn,
      child_structures: [%{id: id} | _]
    } do
      assert %{"data" => %{"siblings" => siblings}} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, id, "latest"))
               |> json_response(:ok)

      assert Enum.count(siblings) == 2
    end

    @tag authenticated_user: @admin_user_name
    test "renders metadata versions when exist", %{
      conn: conn,
      parent_structure: %{id: parent_id},
      structure: %{id: child_id}
    } do
      assert %{"data" => %{"metadata_versions" => []}} =
               conn
               |> get(
                 data_structure_data_structure_version_path(conn, :show, parent_id, "latest")
               )
               |> json_response(:ok)

      assert %{"data" => %{"metadata_versions" => [_v1]}} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, child_id, "latest"))
               |> json_response(:ok)
    end
  end

  describe "show data_structure with deletions in its hierarchy" do
    setup [:create_structure_hierarchy_with_logic_deletions]

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with children including deleted", %{
      conn: conn,
      parent_structure: %{id: parent_id}
    } do
      assert %{"data" => %{"children" => children}} =
               conn
               |> get(
                 data_structure_data_structure_version_path(conn, :show, parent_id, "latest")
               )
               |> json_response(:ok)

      assert Enum.count(children) == 3
      assert [deleted_child] = Enum.filter(children, & &1["deleted_at"])
      assert deleted_child["name"] == "Child_deleted"
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with logic deleted parents", %{
      conn: conn,
      child_structures: [%{id: child_id} | _]
    } do
      assert %{"data" => %{"parents" => [parent]}} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, child_id, "latest"))
               |> json_response(:ok)

      assert parent["name"] != "Parent_deleted"
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with logic deleted siblings", %{
      conn: conn,
      child_structures: [%{id: id} | _]
    } do
      assert %{"data" => %{"siblings" => siblings}} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, id, "latest"))
               |> json_response(:ok)

      assert Enum.count(siblings) == 2
      assert Enum.find(siblings, [], &(Map.get(&1, "name") == "Child_deleted" == []))
    end
  end

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "lists all data_structures", %{conn: conn} do
      assert %{"data" => []} =
               conn
               |> get(data_structure_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authenticated_user: @admin_user_name
    test "search all data_structures", %{conn: conn} do
      assert %{assigns: %{data_structure: %{versions: [dsv | _]}}} =
               post(conn, data_structure_path(conn, :create), data_structure: @create_attrs)

      assert %{"data" => [%{"name" => name}]} =
               conn
               |> get(data_structure_path(conn, :index))
               |> json_response(:ok)

      assert name == dsv.name
    end
  end

  describe "search" do
    setup [:create_data_structure]

    @tag :admin_authenticated
    test "search_all", %{conn: conn, data_structure: %{id: id}} do
      assert %{"data" => [%{"id" => ^id}], "filters" => filters} =
               conn
               |> post(data_structure_path(conn, :search), %{})
               |> json_response(:ok)
    end

    @tag :admin_authenticated
    test "search with query performs ngram search on name", %{conn: conn} do
      %{data_structure_id: id} =
        insert(:data_structure_version,
          name: "foobarbaz",
          data_structure: build(:data_structure, external_id: "foobarbaz")
        )

      assert %{"data" => [%{"id" => ^id}]} =
               conn
               |> post(data_structure_path(conn, :search), %{"query" => "obar"})
               |> json_response(:ok)
    end

    @tag :admin_authenticated
    test "search with query performs search on dynamic content", %{conn: conn} do
      create_template(%{name: "template_name"})

      %{data_structure_id: id} =
        insert(:data_structure_version,
          name: "boofarfaz",
          type: "template_name",
          data_structure:
            build(:data_structure,
              external_id: "boofarfaz",
              df_content: %{"field" => "xyzzy"}
            )
        )

      assert %{"data" => [%{"id" => ^id}]} =
               conn
               |> post(data_structure_path(conn, :search), %{"query" => "xyzz"})
               |> json_response(:ok)
    end
  end

  describe "create data_structure" do
    @tag authenticated_user: @admin_user_name
    test "renders data_structure when data is valid", %{
      conn: conn,
      swagger_schema: schema,
      system: system
    } do
      assert %{"data" => %{"id" => id}} =
               conn
               |> post(data_structure_path(conn, :create), data_structure: @create_attrs)
               |> validate_resp_schema(schema, "DataStructureResponse")
               |> json_response(:created)

      assert %{"data" => data} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, id, "latest"))
               |> validate_resp_schema(schema, "DataStructureVersionResponse")
               |> json_response(:ok)

      assert data["data_structure"]["id"] == id
      assert data["description"] == "some description"
      assert data["data_structure"]["external_id"] == "some external_id"
      assert data["class"] == "some class"
      assert data["type"] == "csv"
      assert data["group"] == "some group"
      assert data["name"] == "some name"
      assert data["system"]["id"] == system.id
      assert data["system"]["name"] == system.name
      assert data["data_structure"]["inserted_at"]
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn} do
      assert %{"errors" => errors} =
               conn
               |> post(data_structure_path(conn, :create), data_structure: @invalid_attrs)
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end
  end

  describe "update data_structure" do
    setup [:create_data_structure]

    @tag authenticated_user: @admin_user_name
    test "renders data_structure when data is valid", %{
      conn: conn,
      data_structure: %{id: id} = data_structure,
      swagger_schema: schema
    } do
      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(data_structure_path(conn, :update, data_structure),
                 data_structure: @update_attrs
               )
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, id, "latest"))
               |> validate_resp_schema(schema, "DataStructureVersionResponse")
               |> json_response(:ok)

      assert data["data_structure"]["id"] == id
      assert data["description"] == "some description"
      assert data["data_structure"]["inserted_at"]
    end

    @tag authenticated_user: @admin_user_name
    test "renders error when df_content is invalid", %{conn: conn, data_structure: data_structure} do
      assert conn
             |> put(data_structure_path(conn, :update, data_structure),
               data_structure: %{df_content: %{}}
             )
             |> response(:unprocessable_entity)
    end

    @tag authenticated_user: @admin_user_name
    test "renders data_structure when df_content is valid", %{
      conn: conn,
      data_structure: %{id: id} = data_structure
    } do
      content = %{"field" => "1"}

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(data_structure_path(conn, :update, data_structure),
                 data_structure: %{df_content: content}
               )
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, id, "latest"))
               |> json_response(:ok)

      assert data["data_structure"]["df_content"] == content
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
      assert conn
             |> delete(data_structure_path(conn, :delete, data_structure))
             |> response(:no_content)

      assert_error_sent(404, fn ->
        conn
        |> get(
          data_structure_data_structure_version_path(conn, :show, data_structure.id, "latest")
        )
        |> validate_resp_schema(schema, "DataStructureResponse")
      end)
    end
  end

  describe "data_structure confidentiality" do
    setup [:create_data_structure]

    @tag authenticated_user: @admin_user_name
    test "updates data_structure confidentiality", %{
      conn: conn,
      data_structure: %{id: id} = data_structure
    } do
      assert Map.get(data_structure, :confidential) == false

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(data_structure_path(conn, :update, data_structure),
                 data_structure: %{confidential: true}
               )
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, id, "latest"))
               |> json_response(:ok)

      assert data["data_structure"]["id"] == id
      assert data["data_structure"]["confidential"] == true
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

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(data_structure_path(conn, :update, data_structure),
                 data_structure: %{df_content: %{"field" => "2"}}
               )
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, id, "latest"))
               |> json_response(:ok)

      assert data["data_structure"]["id"] == id
      assert data["data_structure"]["df_content"] == %{"field" => "2"}
      assert data["domain"]["name"] == "domain_name"
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

      assert conn
             |> put(data_structure_path(conn, :update, data_structure),
               data_structure: %{df_content: %{foo: "bar"}}
             )
             |> json_response(:forbidden)

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

      assert conn
             |> put(data_structure_path(conn, :update, data_structure),
               data_structure: %{confidential: true}
             )
             |> json_response(:ok)

      new_data_structure = DataStructures.get_data_structure!(id)
      assert Map.get(new_data_structure, :confidential) == false
    end
  end

  describe "csv" do
    setup [:create_data_structure]
    @tag authenticated_user: @admin_user_name
    test "gets csv content", %{
      conn: conn,
      data_structure: data_structure,
      data_structure_version: data_structure_version
    } do
      child_structure = insert(:data_structure, external_id: "Child1")

      child_version =
        insert(:data_structure_version,
          data_structure_id: child_structure.id,
          deleted_at: DateTime.utc_now()
        )

      %{id: relation_type_id} = RelationTypes.get_default()

      insert(:data_structure_relation,
        parent_id: data_structure_version.id,
        child_id: child_version.id,
        relation_type_id: relation_type_id
      )

      assert %{resp_body: resp_body} = post(conn, data_structure_path(conn, :csv, %{}))
      assert String.contains?(resp_body, data_structure.external_id)
      assert not String.contains?(resp_body, child_structure.external_id)
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
    insert(:structure_metadata, data_structure_id: structure.id)

    child_structures = [
      insert(:data_structure, external_id: "Child1"),
      insert(:data_structure, external_id: "Child2")
    ]

    parent_version = insert(:data_structure_version, data_structure_id: parent_structure.id)
    structure_version = insert(:data_structure_version, data_structure_id: structure.id)

    child_versions =
      child_structures
      |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

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
      Enum.map(
        children,
        &insert(:data_structure_version,
          data_structure_id: &1.id,
          name: &1.external_id,
          deleted_at: if(&1.external_id == "Child_deleted", do: deleted_at, else: nil)
        )
      )

    %{id: relation_type_id} = RelationTypes.get_default()

    Enum.each(
      child_versions,
      &insert(:data_structure_relation,
        parent_id: parent_version.id,
        child_id: &1.id,
        relation_type_id: relation_type_id
      )
    )

    Enum.each(
      child_versions,
      &insert(:data_structure_relation,
        parent_id: parent_version_deleted.id,
        child_id: &1.id,
        relation_type_id: relation_type_id
      )
    )

    {:ok, parent_structure: parent, child_structures: children}
  end

  defp create_data_structure_and_permissions(user_id, role_name, confidential) do
    domain_name = "domain_name"
    domain_id = :random.uniform(1_000_000)
    updated_at = DateTime.utc_now()
    TaxonomyCache.put_domain(%{name: domain_name, id: domain_id, updated_at: updated_at})

    MockPermissionResolver.create_acl_entry(%{
      principal_id: user_id,
      principal_type: "user",
      resource_id: domain_id,
      resource_type: "domain",
      role_name: role_name
    })

    template_name = "template_name"

    create_template(%{name: template_name})

    data_structure = insert(:data_structure, confidential: confidential, domain_id: domain_id)

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
