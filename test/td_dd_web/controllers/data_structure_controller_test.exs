defmodule TdDdWeb.DataStructureControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import Routes

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Lineage.GraphData

  @moduletag sandbox: :shared
  @template_name "data_structure_controller_test_template"

  setup_all do
    start_supervised!(GraphData)
    :ok
  end

  setup state do
    %{id: template_id, name: template_name} = CacheHelpers.insert_template(name: @template_name)

    system = insert(:system)

    domain =
      case state do
        %{domain: domain} -> domain
        _ -> CacheHelpers.insert_domain()
      end

    CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)

    start_supervised!(TdDd.Search.StructureEnricher)

    [system: system, domain: domain]
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
    setup :create_data_structure

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
      data_structure = insert(:data_structure, external_id: "boofarfaz")

      %{data_structure_id: id} =
        insert(:data_structure_version,
          name: "boofarfaz",
          type: @template_name,
          data_structure: data_structure
        )

      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "xyzzy"},
        status: :published
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
    setup :create_data_structure

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
  end

  describe "delete data_structure" do
    setup :create_data_structure

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

    @tag authentication: [role: "user"]
    test "user without permission can not delete logical data structure", %{
      conn: conn,
      data_structure: %{id: id}
    } do
      assert(
        %{"errors" => error} =
          conn
          |> delete(data_structure_path(conn, :delete, id, %{"logical" => true}))
          |> json_response(:forbidden)
      )

      assert(%{"detail" => "Invalid authorization"} = error)
    end

    @tag authentication: [role: "admin"]
    test "admin can delete logical data structure", %{
      conn: conn,
      data_structure: %{id: id}
    } do
      assert(
        conn
        |> delete(data_structure_path(conn, :delete, id, %{"logical" => true}))
        |> response(:no_content)
      )

      assert %{"data" => %{"deleted_at" => deleted_at}} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, id, "latest"))
               |> json_response(:ok)

      refute is_nil(deleted_at)
    end
  end

  describe "data_structure confidentiality" do
    setup :create_data_structure

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
                 data_structure: %{confidential: false}
               )
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, id, "latest"))
               |> json_response(:ok)

      assert data["data_structure"]["id"] == id
      assert data["data_structure"]["confidential"] == false
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
               data_structure: %{confidential: false}
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
    setup :create_data_structure

    @tag authentication: [role: "admin"]
    test "gets csv content", %{
      conn: conn,
      data_structure: data_structure,
      data_structure_version: data_structure_version
    } do
      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "foo_latest_note", "list" => "two"},
        status: :published
      )

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
      assert String.contains?(resp_body, "foo_latest_note")
      assert not String.contains?(resp_body, child_structure.external_id)
    end

    @tag authentication: [role: "admin"]
    test "gets editable csv content", %{
      conn: conn,
      data_structure: data_structure,
      data_structure_version: data_structure_version
    } do
      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "foo", "list" => "bar"},
        status: :published
      )

      assert %{resp_body: body} = post(conn, data_structure_path(conn, :editable_csv, %{}))

      %{external_id: external_id} = data_structure
      %{name: name, type: type, path: path} = data_structure_version

      assert body == """
             external_id;name;type;path;string;list\r
             #{external_id};#{name};#{type};#{Enum.join(path, "")};foo;bar\r
             """
    end

    @tag authentication: [role: "admin"]
    test "upload, throw error with invalid csv", %{conn: conn} do
      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"}
      )
      |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "upload, valid csv", %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"}
      )
      |> response(:ok)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "upload, can not update without permissions", %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"}
      )
      |> response(:forbidden)
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :create_structure_note,
             :view_data_structure
           ]
         ]
    test "upload, can create structure_notes", %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"}
      )
      |> response(:ok)
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :edit_structure_note,
             :view_data_structure
           ]
         ]
    test "upload, can edit structure_notes", %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "xyzzy", "list" => "two"},
        status: :draft
      )

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"}
      )
      |> response(:ok)
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :create_structure_note,
             :view_data_structure
           ]
         ]
    test "upload, can create structure_notes with a previous published note", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "xyzzy", "list" => "two"},
        status: :published
      )

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"}
      )
      |> response(:ok)

      latest_note = DataStructures.get_latest_structure_note(data_structure.id)
      assert latest_note.status == :draft
      assert latest_note.df_content == %{"string" => "the new content from csv", "list" => "one"}
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :create_structure_note,
             :view_data_structure,
             :publish_structure_note_from_draft
           ]
         ]
    test "upload, can create and auto-publish structure_notes", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "xyzzy", "list" => "two"},
        status: :published
      )

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"},
        auto_publish: "true"
      )
      |> response(:ok)

      latest_note = DataStructures.get_latest_structure_note(data_structure.id)
      assert latest_note.status == :published
      assert latest_note.df_content == %{"string" => "the new content from csv", "list" => "one"}

      assert data_structure.id
             |> DataStructures.list_structure_notes(:versioned)
             |> Enum.count() == 1
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :create_structure_note,
             :view_data_structure
           ]
         ]
    test "upload, can not create and auto-publish structure_notes without draft_to_publish permission",
         %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "xyzzy", "list" => "two"},
        status: :published
      )

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"},
        auto_publish: "true"
      )
      |> response(:forbidden)
    end
  end

  defp create_data_structure(%{domain: %{id: domain_id}} = tags) do
    data_structure =
      insert(:data_structure,
        confidential: Map.get(tags, :confidential, false),
        domain_id: domain_id
      )

    create_data_structure(data_structure)
  end

  defp create_data_structure(%DataStructure{} = data_structure) do
    data_structure_version =
      insert(:data_structure_version, data_structure_id: data_structure.id, type: @template_name)

    [data_structure: data_structure, data_structure_version: data_structure_version]
  end
end
