defmodule TdDdWeb.SystemControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import Mox

  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Systems.System, as: TdDdSystem

  @moduletag sandbox: :shared
  @create_attrs %{
    external_id: "some external_id",
    name: "some name"
  }
  @update_attrs %{
    external_id: "some updated external_id",
    name: "some updated name"
  }
  @invalid_attrs %{external_id: nil, name: nil}
  @valid_image <<"data:image/jpeg;base64,/888j/4QAYRXhXXXX">>
  @invalid_image <<"data:application/pdf;base64,JVBERi0xLjUNJeLj">>

  @system_template %{
    id: System.unique_integer([:positive]),
    label: "system",
    name: "System",
    scope: "dd",
    content: [
      %{
        "name" => "System Template",
        "fields" => [
          %{
            "cardinality" => "?",
            "label" => "Description",
            "name" => "system_description",
            "type" => "enriched_text",
            "widget" => "enriched_text"
          },
          %{
            "cardinality" => "?",
            "default" => "",
            "label" => "image_label",
            "name" => "image_name",
            "type" => "image",
            "values" => nil,
            "widget" => "image"
          }
        ]
      }
    ]
  }

  @identifier_template %{
    id: System.unique_integer([:positive]),
    label: "identifier_test",
    name: "System",
    scope: "dd",
    content: [
      %{
        "name" => "System Template",
        "fields" => [
          %{
            "cardinality" => "1",
            "label" => "identifier_field",
            "name" => "identifier_field",
            "subscribable" => false,
            "type" => "string",
            "values" => nil,
            "widget" => "identifier"
          }
        ]
      }
    ]
  }

  setup_all do
    start_supervised!(TdDd.Cache.SystemLoader)
    :ok
  end

  setup :verify_on_exit!

  setup tags do
    start_supervised!(TdDd.Search.StructureEnricher)
    system = insert(:system)
    domain = Map.get(tags, :domain, CacheHelpers.insert_domain())
    template = CacheHelpers.insert_template(@system_template)

    [system: system, domain: domain, template: template]
  end

  describe "GET /api/systems" do
    @tag authentication: [role: "admin"]
    test "admin can lists systems", %{conn: conn, swagger_schema: schema} do
      expect_search()

      assert %{"data" => [_system]} =
               conn
               |> get(Routes.system_path(conn, :index))
               |> validate_resp_schema(schema, "SystemsResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "service"]
    test "service account can lists systems", %{conn: conn, swagger_schema: schema} do
      expect_search()

      assert %{"data" => [_system]} =
               conn
               |> get(Routes.system_path(conn, :index))
               |> validate_resp_schema(schema, "SystemsResponse")
               |> json_response(:ok)
    end
  end

  describe "create system" do
    @tag authentication: [role: "admin"]
    test "renders system when data is valid", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => %{"id" => _id}} =
               conn
               |> post(Routes.system_path(conn, :create), system: @create_attrs)
               |> validate_resp_schema(schema, "SystemResponse")
               |> json_response(:created)
    end

    @tag authentication: [role: "admin"]
    test "renders system when image file is valid", %{conn: conn, swagger_schema: schema} do
      valid_attr =
        @create_attrs
        |> new_attr_external_id()
        |> Map.put("df_content", %{"image_name" => @valid_image})

      assert %{"data" => %{"id" => _id}} =
               conn
               |> post(Routes.system_path(conn, :create), system: valid_attr)
               |> validate_resp_schema(schema, "SystemResponse")
               |> json_response(:created)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      assert %{"errors" => _errors} =
               conn
               |> post(Routes.system_path(conn, :create), system: @invalid_attrs)
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when image file is invalid", %{conn: conn} do
      invalid_attr =
        @create_attrs
        |> Map.put("df_content", %{"image_name" => @invalid_image})

      assert %{"errors" => errors} =
               conn
               |> post(Routes.system_path(conn, :create), system: invalid_attr)
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end

    @tag authentication: [role: "admin"]
    test "generates identifier widget", %{conn: conn, swagger_schema: schema} do
      CacheHelpers.insert_template(@identifier_template)

      valid_attr =
        @create_attrs
        |> new_attr_external_id()
        |> Map.put("df_content", %{})

      assert %{
               "data" => %{"id" => _id, "df_content" => %{"identifier_field" => identifier_value}}
             } =
               conn
               |> post(Routes.system_path(conn, :create), system: valid_attr)
               |> validate_resp_schema(schema, "SystemResponse")
               |> json_response(:created)

      refute is_nil(identifier_value)
    end

    @tag authentication: [role: "admin"]
    test "renders system when template not exists", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => %{"id" => _id}} =
               conn
               |> post(Routes.system_path(conn, :create), system: @create_attrs)
               |> validate_resp_schema(schema, "SystemResponse")
               |> json_response(:created)
    end
  end

  describe "update system" do
    @tag authentication: [role: "admin"]
    test "renders system when data is valid", %{
      conn: conn,
      swagger_schema: schema,
      system: %TdDdSystem{id: id} = system
    } do
      assert %{"data" => data} =
               conn
               |> put(Routes.system_path(conn, :update, system), system: @update_attrs)
               |> validate_resp_schema(schema, "SystemResponse")
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "external_id" => "some updated external_id",
               "name" => "some updated name",
               "df_content" => nil
             } = data
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn, system: system} do
      assert %{"errors" => errors} =
               conn
               |> put(Routes.system_path(conn, :update, system), system: @invalid_attrs)
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end

    @tag authentication: [role: "admin"]
    test "renders system when image file is valid", %{
      conn: conn,
      swagger_schema: schema,
      system: %TdDdSystem{id: id} = system
    } do
      valid_attr = @update_attrs |> Map.put("df_content", %{"image_name" => @valid_image})

      assert %{"data" => data} =
               conn
               |> put(Routes.system_path(conn, :update, system), system: valid_attr)
               |> validate_resp_schema(schema, "SystemResponse")
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "external_id" => "some updated external_id",
               "name" => "some updated name",
               "df_content" => %{"image_name" => @valid_image}
             } = data

      valid_attr = @update_attrs |> Map.put("df_content", %{"image_name" => nil})

      assert %{"data" => data} =
               conn
               |> put(Routes.system_path(conn, :update, system), system: valid_attr)
               |> validate_resp_schema(schema, "SystemResponse")
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "external_id" => "some updated external_id",
               "name" => "some updated name",
               "df_content" => %{"image_name" => nil}
             } = data
    end

    @tag authentication: [role: "admin"]
    test "renders errors when image file is invalid", %{conn: conn, system: system} do
      invalid_attr = @update_attrs |> Map.put("df_content", %{"image_name" => @invalid_image})

      assert %{"errors" => errors} =
               conn
               |> put(Routes.system_path(conn, :update, system), system: invalid_attr)
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end
  end

  describe "delete system" do
    @tag authentication: [role: "admin"]
    test "deletes chosen system", %{conn: conn, system: system} do
      assert conn
             |> delete(Routes.system_path(conn, :delete, system))
             |> response(:no_content)
    end

    @tag authentication: [role: "admin"]
    test "returns not_found if system does not exist", %{conn: conn} do
      assert %{"errors" => _errors} =
               conn
               |> delete(Routes.system_path(conn, :delete, -1))
               |> json_response(:not_found)
    end
  end

  describe "get system structures" do
    @tag authentication: [role: "admin"]
    test "will filter structures by system", %{conn: conn, system: system} do
      ds = insert(:data_structure, system_id: system.id, external_id: "struc1")
      dsv = insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      system2 = insert(:system)
      ds = insert(:data_structure, system_id: system2.id, external_id: "struc2")
      insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      expect_search(dsv)

      assert %{"data" => data} =
               conn
               |> get(Routes.system_data_structure_path(conn, :get_system_structures, system))
               |> json_response(:ok)

      assert [%{"name" => "struc1"}] = data
    end

    @tag authentication: [role: "admin"]
    test "will retrieve only root structures", %{conn: conn, system: system} do
      ds = insert(:data_structure, system_id: system.id, external_id: "parent")
      parent = insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      ds = insert(:data_structure, system_id: system.id, external_id: "child")
      child = insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: child.id,
        relation_type_id: RelationTypes.default_id!()
      )

      Hierarchy.update_hierarchy([child.id, parent.id])

      expect_search(parent)

      assert %{"data" => data} =
               conn
               |> get(Routes.system_data_structure_path(conn, :get_system_structures, system))
               |> json_response(:ok)

      assert [%{"name" => "parent"}] = data
    end

    @tag authentication: [role: "admin"]
    test "will not break when structure has no versions", %{conn: conn, system: system} do
      insert(:data_structure, system_id: system.id, external_id: "parent")

      expect_search()

      assert %{"data" => []} =
               conn
               |> get(Routes.system_data_structure_path(conn, :get_system_structures, system))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "non_admin_user", permissions: ["view_data_structure"]]
    test "will filter by permissions for non admin users", %{conn: conn, domain: %{id: domain_id}} do
      %{id: system_id} = insert(:system)

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/structures/_search", %{from: 0, size: 1000, query: query}, _ ->
          assert query == %{
                   bool: %{
                     must: [
                       %{term: %{"system_id" => system_id}},
                       %{term: %{"confidential" => false}},
                       %{term: %{"domain_ids" => domain_id}}
                     ],
                     must_not: [%{exists: %{field: "deleted_at"}}, %{exists: %{field: "path"}}]
                   }
                 }

          SearchHelpers.hits_response([])
      end)

      assert %{"data" => []} =
               conn
               |> get(Routes.system_data_structure_path(conn, :get_system_structures, system_id))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "includes classes in response", %{conn: conn, system: %{id: system_id}} do
      %{name: name, class: class, data_structure_version: dsv} =
        insert(:structure_classification,
          data_structure_version:
            build(:data_structure_version,
              data_structure: build(:data_structure, system_id: system_id)
            )
        )

      expect_search(dsv)

      assert %{"data" => [data]} =
               conn
               |> get(Routes.system_data_structure_path(conn, :get_system_structures, system_id))
               |> json_response(:ok)

      assert %{"classes" => classes} = data
      assert classes == %{name => class}
    end
  end

  defp new_attr_external_id(attrs) do
    attrs |> Map.put(:external_id, Integer.to_string(System.unique_integer([:positive])))
  end

  defp expect_search(results \\ nil) do
    ElasticsearchMock
    |> expect(:request, fn _, :post, "/structures/_search", _, _ ->
      results
      |> List.wrap()
      |> SearchHelpers.hits_response()
    end)
  end
end
