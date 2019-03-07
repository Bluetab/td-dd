defmodule TdDdWeb.DataStructureControllerTest do
  use TdDdWeb.ConnCase
  import TdDdWeb.Authentication, only: :functions
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.MockTaxonomyCache
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService

  @df_cache Application.get_env(:td_dd, :df_cache)

  @create_attrs %{
    description: "some description",
    group: "some group",
    last_change_at: "2010-04-17 14:00:00.000000Z",
    last_change_by: 42,
    name: "some name",
    system: "some system",
    type: "csv",
    ou: "GM"
  }
  @update_attrs %{
    description: "some updated description",
    group: "some updated group",
    last_change_at: "2011-05-18 15:01:01.000000Z",
    last_change_by: 43,
    name: "some updated name",
    system: "some updated system",
    type: "table",
    ou: "EM"
  }
  @invalid_attrs %{
    description: nil,
    group: nil,
    last_change_at: nil,
    last_change_by: nil,
    name: nil,
    system: nil,
    type: nil,
    ou: nil
  }

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockTdAuditService)
    start_supervised(MockPermissionResolver)
    start_supervised(MockTaxonomyCache)
    start_supervised(@df_cache)
    :ok
  end

  setup %{conn: conn} do
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
      conn = get(conn, data_structure_path(conn, :show, child_id))
      %{"children" => children} = json_response(conn, 200)["data"]
      assert Enum.count(children) == 2
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with parents", %{
      conn: conn,
      structure: %DataStructure{id: child_id}
    } do
      conn = get(conn, data_structure_path(conn, :show, child_id))
      %{"parents" => parents} = json_response(conn, 200)["data"]
      assert Enum.count(parents) == 1
    end

    @tag authenticated_user: @admin_user_name
    test "renders a data structure with siblings", %{
      conn: conn,
      child_structures: [%DataStructure{id: id} | _]
    } do
      conn = get(conn, data_structure_path(conn, :show, id))
      %{"siblings" => siblings} = json_response(conn, 200)["data"]
      assert Enum.count(siblings) == 2
    end
  end

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "lists all data_structures", %{conn: conn} do
      conn = get(conn, data_structure_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end

    @tag authenticated_user: @admin_user_name
    test "search all data_structures", %{conn: conn} do
      conn = post(conn, data_structure_path(conn, :create), data_structure: @create_attrs)
      data_structure = conn.assigns.data_structure
      search_params = %{ou: " one§ tow §  #{data_structure.ou}"}

      conn = recycle_and_put_headers(conn)

      conn = get(conn, data_structure_path(conn, :index, search_params))
      json_response = json_response(conn, 200)["data"]
      assert length(json_response) == 1
      json_response = Enum.at(json_response, 0)
      assert json_response["name"] == data_structure.name
    end
  end

  describe "create data_structure" do
    @tag authenticated_user: @admin_user_name
    test "renders data_structure when data is valid", %{conn: conn, swagger_schema: schema} do
      conn = post(conn, data_structure_path(conn, :create), data_structure: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]
      validate_resp_schema(conn, schema, "DataStructureResponse")

      conn = recycle_and_put_headers(conn)

      conn = get(conn, data_structure_path(conn, :show, id))
      json_response_data = conn |> json_response(200) |> Map.get("data")

      json_response_data =
        json_response_data
        |> Map.drop(["last_change_by", "last_change_at"])

      validate_resp_schema(conn, schema, "DataStructureResponse")
      assert json_response_data["id"] == id
      assert json_response_data["description"] == "some description"
      assert json_response_data["type"] == "csv"
      assert json_response_data["ou"] == "GM"
      assert json_response_data["group"] == "some group"
      assert json_response_data["name"] == "some name"
      assert json_response_data["system"] == "some system"
      assert json_response_data["inserted_at"]
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, data_structure_path(conn, :create), data_structure: @invalid_attrs)
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
          data_structure_path(conn, :update, data_structure),
          data_structure: @update_attrs
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, data_structure_path(conn, :show, id))
      json_response_data = json_response(conn, 200)["data"]

      json_response_data =
        json_response_data
        |> Map.delete("last_change_by")
        |> Map.delete("last_change_at")

      validate_resp_schema(conn, schema, "DataStructureResponse")
      assert json_response_data["id"] == id
      assert json_response_data["description"] == "some updated description"
      assert json_response_data["inserted_at"]
    end

    @tag authenticated_user: @admin_user_name
    test "renders error when df_content is invalid", %{
      conn: conn,
      data_structure: data_structure
    } do
      template_name = "template_name"
      @df_cache.clean_cache()

      @df_cache.put_template(%{
        id: 0,
        label: "some label",
        name: template_name,
        is_default: false,
        content: [
          %{
            "name" => "field",
            "type" => "string",
            "cardinality" => "1"
          }
        ]
      })

      conn =
        put(
          conn,
          data_structure_path(conn, :update, data_structure),
          data_structure: %{
            df_name: template_name,
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
      template_name = "template_name"
      @df_cache.clean_cache()

      @df_cache.put_template(%{
        id: 0,
        label: "some label",
        name: template_name,
        is_default: false,
        content: [
          %{
            "name" => "field",
            "type" => "string",
            "cardinality" => "1"
          }
        ]
      })

      df_content = %{"field" => "value"}

      conn =
        put(
          conn,
          data_structure_path(conn, :update, data_structure),
          data_structure: %{
            df_name: template_name,
            df_content: df_content
          }
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)
      conn = get(conn, data_structure_path(conn, :show, id))
      json_response_data = json_response(conn, 200)["data"]

      assert json_response_data["df_content"] == df_content
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
      conn = delete(conn, data_structure_path(conn, :delete, data_structure))
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent(404, fn ->
        get(conn, data_structure_path(conn, :show, data_structure))
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
          data_structure_path(conn, :update, data_structure),
          data_structure: %{confidential: true}
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      conn = recycle_and_put_headers(conn)

      conn = get(conn, data_structure_path(conn, :show, id))
      json_response_data = json_response(conn, 200)["data"]

      assert json_response_data["id"] == id
      assert json_response_data["confidential"] == true
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
          data_structure_path(conn, :update, data_structure),
          data_structure: %{description: "edited desc"}
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
      conn = recycle_and_put_headers(conn)

      conn = get(conn, data_structure_path(conn, :show, id))
      json_response_data = json_response(conn, 200)["data"]

      assert json_response_data["id"] == id
      assert json_response_data["description"] == "edited desc"
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
          data_structure_path(conn, :update, data_structure),
          data_structure: %{description: "edited desc"}
        )

      assert json_response(conn, 403)
      new_data_structure = DataStructures.get_data_structure!(id)
      assert Map.get(new_data_structure, :description) == "some description"
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
          data_structure_path(conn, :update, data_structure),
          data_structure: %{confidential: true}
        )

      assert json_response(conn, 200)
      new_data_structure = DataStructures.get_data_structure!(id)
      assert Map.get(new_data_structure, :confidential) == false
    end
  end

  defp create_data_structure(_) do
    data_structure = insert(:data_structure)
    data_structure_version = insert(:data_structure_version, data_structure_id: data_structure.id)
    {:ok, data_structure: data_structure, data_structure_version: data_structure_version}
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

  defp create_data_structure_and_permissions(user_id, role_name, confidential) do
    domain_name = "domain_name"
    domain_id = 1
    MockTaxonomyCache.create_domain(%{name: domain_name, id: domain_id})

    MockPermissionResolver.create_acl_entry(%{
      principal_id: user_id,
      principal_type: "user",
      resource_id: domain_id,
      resource_type: "domain",
      role_name: role_name
    })

    data_structure =
      insert(
        :data_structure,
        confidential: confidential,
        name: "confidential",
        ou: domain_name,
        domain_id: domain_id
      )

    insert(:data_structure_version, data_structure_id: data_structure.id)
    data_structure
  end
end
