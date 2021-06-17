defmodule TdDdWeb.DataStructureControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import Routes

  alias TdCache.TemplateCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Lineage.GraphData

  @moduletag sandbox: :shared
  @template_name "data_structure_controller_test_template"

  setup_all do
    start_supervised!(GraphData)
    :ok
  end

  setup %{conn: conn} do
    %{id: template_id, name: template_name} = template = build(:template, name: @template_name)
    {:ok, _} = TemplateCache.put(template, publish: false)
    system = insert(:system)
    domain = CacheHelpers.insert_domain()
    CacheHelpers.insert_structure_type(structure_type: template_name, template_id: template_id)
    on_exit(fn -> TemplateCache.delete(template_id) end)

    start_supervised!(TdDd.Search.StructureEnricher)

    {:ok,
     %{conn: put_req_header(conn, "accept", "application/json"), system: system, domain: domain}}
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

    @tag authentication: [role: "user"]
    test "renders data_structure when data is valid", %{
      conn: conn,
      claims: %{user_id: user_id},
      data_structure: %{id: id, domain_id: domain_id} = data_structure,
      swagger_schema: schema
    } do
      attrs = %{domain_id: 42, confidential: true}

      create_acl_entry(user_id, domain_id, [
        :update_data_structure,
        :manage_confidential_structures,
        :manage_structures_domain
      ])

      create_acl_entry(user_id, 42, [
        :view_data_structure,
        :manage_confidential_structures,
        :manage_structures_domain
      ])

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(data_structure_path(conn, :update, data_structure), data_structure: attrs)
               |> validate_resp_schema(schema, "DataStructureResponse")
               |> json_response(:ok)

      assert %{domain_id: 42, confidential: true} = DataStructures.get_data_structure!(id)
    end

    @tag authentication: [role: "user"]
    test "needs manage_confidential_structures permission", %{
      conn: conn,
      claims: %{user_id: user_id},
      data_structure: %{domain_id: domain_id} = data_structure,
      swagger_schema: schema
    } do
      attrs = %{confidential: true}

      # NO , :manage_confidential_structures,])
      create_acl_entry(user_id, domain_id, [:view_data_structure, :update_data_structure])

      assert conn
             |> put(data_structure_path(conn, :update, data_structure), data_structure: attrs)
             |> validate_resp_schema(schema, "DataStructureResponse")
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "user"]
    test "needs manage_structures_domain permission", %{
      conn: conn,
      claims: %{user_id: user_id},
      data_structure: %{domain_id: domain_id} = data_structure,
      swagger_schema: schema
    } do
      attrs = %{domain_id: 42}

      # NO #, :manage_structures_domain])
      create_acl_entry(user_id, domain_id, [:update_data_structure])

      create_acl_entry(user_id, 42, [
        :view_data_structure,
        :manage_structures_domain,
        :manage_confidential_structures
      ])

      assert conn
             |> put(data_structure_path(conn, :update, data_structure), data_structure: attrs)
             |> validate_resp_schema(schema, "DataStructureResponse")
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "user"]
    test "needs access to new domain", %{
      conn: conn,
      claims: %{user_id: user_id},
      data_structure: %{domain_id: domain_id} = data_structure,
      swagger_schema: schema
    } do
      attrs = %{domain_id: 42}

      create_acl_entry(user_id, domain_id, [
        :update_data_structure,
        :manage_structures_domain
      ])

      create_acl_entry(user_id, 42, [:view_data_structure, :manage_confidential_structures])

      assert conn
             |> put(data_structure_path(conn, :update, data_structure), data_structure: attrs)
             |> validate_resp_schema(schema, "DataStructureResponse")
             |> json_response(:forbidden)
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
      assert data["data_structure"]["domain"]["name"] == domain_name
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
           data_structure: %{id: data_structure_id}
         } do
      create_acl_entry(user_id, domain_id, [:view_data_structure, :update_data_structure])

      assert conn
             |> put(data_structure_path(conn, :update, data_structure_id),
               data_structure: %{confidential: true}
             )
             |> json_response(:forbidden)
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

      insert(:data_structure_relation,
        parent_id: data_structure_version.id,
        child_id: child_version.id,
        relation_type_id: RelationTypes.default_id!()
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
end
