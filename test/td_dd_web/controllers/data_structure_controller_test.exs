defmodule TdDdWeb.DataStructureControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import Routes

  alias TdCache.StructureTypeCache
  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Lineage.GraphData

  @template_name "data_structure_controller_test_template"

  @update_attrs %{
    description: "some updated description",
    group: "some updated group",
    last_change_by: 43,
    name: "some updated name",
    type: "table"
  }

  setup_all do
    start_supervised(GraphData)

    %{id: domain_id} = domain = build(:domain)
    TaxonomyCache.put_domain(domain)

    on_exit(fn ->
      TaxonomyCache.delete_domain(domain_id)
    end)

    [domain: domain]
  end

  setup %{conn: conn} do
    %{id: template_id, name: template_name} = template = build(:template, name: @template_name)
    {:ok, _} = TemplateCache.put(template, publish: false)
    system = insert(:system)

    %{id: structure_type_id} =
      structure_type =
      insert(:data_structure_type, structure_type: template_name, template_id: template_id)

    StructureTypeCache.put(structure_type)

    on_exit(fn ->
      TemplateCache.delete(template_id)
      StructureTypeCache.delete(structure_type_id)
    end)

    {:ok, %{conn: put_req_header(conn, "accept", "application/json"), system: system}}
  end

  describe "show" do
    setup [:create_structure_hierarchy]

    @tag authentication: [role: "admin"]
    test "renders a data structure with children", %{conn: conn, structure: %{id: child_id}} do
      assert %{"data" => %{"children" => children}} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, child_id, "latest"))
               |> json_response(:ok)

      assert Enum.count(children) == 2
      assert Enum.all?(children, &(Map.get(&1, "order") == 1))
    end

    @tag authentication: [role: "admin"]
    test "renders a data structure with parents", %{conn: conn, structure: %{id: child_id}} do
      assert %{"data" => %{"parents" => parents}} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, child_id, "latest"))
               |> json_response(:ok)

      assert Enum.count(parents) == 1
    end

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "admin"]
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
    @tag authentication: [role: "admin"]
    test "lists all data_structures", %{conn: conn} do
      assert %{"data" => []} =
               conn
               |> get(data_structure_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "search all data_structures", %{conn: conn} do
      %{name: name, data_structure: %{id: id, external_id: external_id}} =
        insert(:data_structure_version)

      assert %{"data" => data} =
               conn
               |> get(data_structure_path(conn, :index))
               |> json_response(:ok)

      assert [%{"id" => ^id, "name" => ^name, "external_id" => ^external_id}] = data
    end

    @tag authentication: [role: "service"]
    test "service account can search all data_structures", %{conn: conn} do
      %{name: name, data_structure: %{id: id, external_id: external_id}} =
        insert(:data_structure_version)

      assert %{"data" => data} =
               conn
               |> get(data_structure_path(conn, :index))
               |> json_response(:ok)

      assert [%{"id" => ^id, "name" => ^name, "external_id" => ^external_id}] = data
    end
  end

  describe "search" do
    setup [:create_data_structure]

    @tag authentication: [role: "admin"]
    test "search_all", %{conn: conn, data_structure: %{id: id}} do
      assert %{"data" => [%{"id" => ^id}], "filters" => _filters} =
               conn
               |> post(data_structure_path(conn, :search), %{})
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "admin"]
    test "search with query performs search on dynamic content", %{conn: conn} do
      %{data_structure_id: id} =
        insert(:data_structure_version,
          name: "boofarfaz",
          type: @template_name,
          data_structure:
            build(:data_structure,
              external_id: "boofarfaz",
              df_content: %{"string" => "xyzzy"}
            )
        )

      assert %{"data" => [%{"id" => ^id}]} =
               conn
               |> post(data_structure_path(conn, :search), %{"query" => "xyzz"})
               |> json_response(:ok)
    end
  end

  describe "search with scroll" do
    setup do
      Enum.each(1..7, fn _ -> insert(:data_structure_version) end)
    end

    @tag authentication: [role: "admin"]
    test "returns scroll_id and pages results", %{conn: conn} do
      assert %{"data" => data, "scroll_id" => scroll_id} =
               conn
               |> post(data_structure_path(conn, :search), %{
                 "filters" => %{"all" => true},
                 "size" => 5,
                 "scroll" => "1m"
               })
               |> json_response(:ok)

      assert length(data) == 5

      assert %{"data" => data, "scroll_id" => scroll_id} =
               conn
               |> post(data_structure_path(conn, :search), %{
                 "scroll_id" => scroll_id,
                 "scroll" => "1m"
               })
               |> json_response(:ok)

      assert length(data) == 2

      assert %{"data" => [], "scroll_id" => _scroll_id} =
               conn
               |> post(data_structure_path(conn, :search), %{
                 "scroll_id" => scroll_id,
                 "scroll" => "1m"
               })
               |> json_response(:ok)
    end
  end

  describe "update data_structure" do
    setup [:create_data_structure]

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "admin"]
    test "renders error when df_content is invalid", %{conn: conn, data_structure: data_structure} do
      assert conn
             |> put(data_structure_path(conn, :update, data_structure),
               data_structure: %{df_content: %{}}
             )
             |> response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "admin"]
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

    @tag authentication: [user_name: "non_admin_user"]
    @tag :confidential
    test "user with permission can update confidential data_structure", %{
      conn: conn,
      claims: %{user_id: user_id},
      domain: %{id: domain_id, name: domain_name},
      data_structure: %{id: id, confidential: true}
    } do
      create_acl_entry(user_id, domain_id, [
        :view_data_structure,
        :update_data_structure,
        :manage_confidential_structures
      ])

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(data_structure_path(conn, :update, id),
                 data_structure: %{df_content: %{"string" => "foo", "list" => "one"}}
               )
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, id, "latest"))
               |> json_response(:ok)

      assert data["data_structure"]["id"] == id
      assert data["data_structure"]["df_content"] == %{"list" => "one", "string" => "foo"}
      assert data["domain"]["name"] == domain_name
    end

    @tag authentication: [user_name: "user_without_permission"]
    @tag :confidential
    test "user without confidential permission cannot update confidential data_structure", %{
      conn: conn,
      claims: %{user_id: user_id},
      domain: %{id: domain_id},
      data_structure: %{id: data_structure_id, confidential: true}
    } do
      create_acl_entry(user_id, domain_id, [:view_data_structure, :update_data_structure])

      assert conn
             |> put(data_structure_path(conn, :update, data_structure_id),
               data_structure: %{df_content: %{foo: "bar"}}
             )
             |> json_response(:forbidden)
    end

    @tag authentication: [user_name: "user_without_confidential"]
    test "user without confidential permission cannot update confidentiality of data_structure",
         %{
           conn: conn,
           claims: %{user_id: user_id},
           domain: %{id: domain_id},
           data_structure: %{id: data_structure_id, confidential: false}
         } do
      create_acl_entry(user_id, domain_id, [:view_data_structure, :update_data_structure])

      assert conn
             |> put(data_structure_path(conn, :update, data_structure_id),
               data_structure: %{confidential: true}
             )
             |> json_response(:ok)

      new_data_structure = DataStructures.get_data_structure!(data_structure_id)
      assert Map.get(new_data_structure, :confidential) == false
    end
  end

  describe "csv" do
    setup [:create_data_structure]
    @tag authentication: [role: "admin"]
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

  defp create_data_structure(%{domain: %{id: domain_id}} = tags) do
    data_structure =
      insert(:data_structure,
        df_content: %{"field" => "1"},
        confidential: Map.get(tags, :confidential, false),
        domain_id: domain_id
      )

    data_structure_version =
      insert(:data_structure_version, data_structure_id: data_structure.id, type: @template_name)

    [data_structure: data_structure, data_structure_version: data_structure_version]
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
      |> Enum.map(
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

  defp create_acl_entry(user_id, domain_id, permissions) do
    MockPermissionResolver.create_acl_entry(%{
      principal_id: user_id,
      principal_type: "user",
      resource_id: domain_id,
      resource_type: "domain",
      permissions: permissions
    })
  end
end
