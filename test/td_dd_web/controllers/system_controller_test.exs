defmodule TdDdWeb.SystemControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.Cache.SystemLoader
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

  setup_all do
    start_supervised(SystemLoader)
    :ok
  end

  setup %{conn: conn} do
    start_supervised!(TdDd.Search.StructureEnricher)
    system = insert(:system)
    domain = CacheHelpers.insert_domain()
    template = CacheHelpers.insert_template(@system_template)

    {:ok,
     conn: put_req_header(conn, "accept", "application/json"),
     system: system,
     domain: domain,
     template: template}
  end

  describe "GET /api/systems" do
    @tag authentication: [role: "admin"]
    test "admin can lists systems", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => [_system]} =
               conn
               |> get(Routes.system_path(conn, :index))
               |> validate_resp_schema(schema, "SystemsResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "service"]
    test "service account can lists systems", %{conn: conn, swagger_schema: schema} do
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
    test "renders system when template not exists", %{
      conn: conn,
      swagger_schema: schema,
      template: %{id: template_id}
    } do
      TdCache.TemplateCache.delete(template_id)

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
      insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

      system2 = insert(:system)
      ds = insert(:data_structure, system_id: system2.id, external_id: "struc2")
      insert(:data_structure_version, data_structure_id: ds.id, name: ds.external_id)

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

      assert %{"data" => data} =
               conn
               |> get(Routes.system_data_structure_path(conn, :get_system_structures, system))
               |> json_response(:ok)

      assert [%{"name" => "parent"}] = data
    end

    @tag authentication: [role: "admin"]
    test "will not break when structure has no versions", %{conn: conn, system: system} do
      insert(:data_structure, system_id: system.id, external_id: "parent")

      assert %{"data" => []} =
               conn
               |> get(Routes.system_data_structure_path(conn, :get_system_structures, system))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "will filter by permissions for non admin users", %{
      conn: conn,
      claims: %{user_id: user_id},
      domain: %{id: domain_id}
    } do
      create_acl_entry(user_id, domain_id, [])

      %{data_structure: %{id: id, system_id: system_id}} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, domain_id: domain_id)
        )

      assert %{"data" => data} =
               conn
               |> get(Routes.system_data_structure_path(conn, :get_system_structures, system_id))
               |> json_response(:ok)

      refute data |> Enum.map(& &1["id"]) |> Enum.member?(id)
    end

    @tag authentication: [role: "admin"]
    test "includes classes in response", %{conn: conn, system: %{id: system_id}} do
      %{name: name, class: class} =
        insert(:structure_classification,
          data_structure_version:
            build(:data_structure_version,
              data_structure: build(:data_structure, system_id: system_id)
            )
        )

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
end
