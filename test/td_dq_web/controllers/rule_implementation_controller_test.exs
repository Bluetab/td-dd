defmodule TdDqWeb.RuleImplementationControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"
  import TdDq.Factory
  import TdDqWeb.Authentication, only: :functions

  @invalid_quality_control_id -1

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all quality_rules", %{conn: conn, swagger_schema: schema} do
      conn = get(conn, rule_implementation_path(conn, :index))
      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create quality_rule" do
    @tag :admin_authenticated
    test "renders quality_rule when data is valid", %{conn: conn, swagger_schema: schema} do
      quality_control = insert(:quality_control)
      quality_rule_type = insert(:quality_rule_type)

      creation_attrs =
        Map.from_struct(
          build(
            :quality_rule,
            quality_control_id: quality_control.id,
            quality_rule_type_id: quality_rule_type.id
          )
        )

      conn = post(conn, rule_implementation_path(conn, :create), quality_rule: creation_attrs)
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, rule_implementation_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      json_response = json_response(conn, 200)["data"]

      assert creation_attrs[:quality_control_id] == json_response["quality_control_id"]
      assert creation_attrs[:description] == json_response["description"]
      assert creation_attrs[:system_params] == json_response["system_params"]
      assert creation_attrs[:system] == json_response["system"]
      assert creation_attrs[:type] == json_response["type"]
      assert creation_attrs[:tag] == json_response["tag"]
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      quality_control = insert(:quality_control)

      creation_attrs =
        Map.from_struct(
          build(:quality_rule, quality_control_id: quality_control.id, name: nil, system: nil)
        )

      conn = post(conn, rule_implementation_path(conn, :create), quality_rule: creation_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update quality_rule" do
    @tag :admin_authenticated
    test "renders quality_rule when data is valid", %{conn: conn, swagger_schema: schema} do
      quality_rule = insert(:quality_rule)
      update_attrs = Map.from_struct(quality_rule)

      update_attrs =
        update_attrs
        |> Map.put(:name, "New name")
        |> Map.put(:system, "New system")
        |> Map.put(:description, "New description")

      conn = put(conn, rule_implementation_path(conn, :update, quality_rule), quality_rule: update_attrs)
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert %{"id" => id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, rule_implementation_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      json_response = json_response(conn, 200)["data"]

      assert update_attrs[:quality_control_id] == json_response["quality_control_id"]
      assert update_attrs[:description] == json_response["description"]
      assert update_attrs[:system_params] == json_response["system_params"]
      assert update_attrs[:system] == json_response["system"]
      assert update_attrs[:tag] == json_response["tag"]
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      quality_rule = insert(:quality_rule)
      update_attrs = Map.from_struct(quality_rule)

      update_attrs =
        update_attrs
        |> Map.put(:name, nil)
        |> Map.put(:system, nil)

      conn = put(conn, rule_implementation_path(conn, :update, quality_rule), quality_rule: update_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete quality_rule" do
    @tag :admin_authenticated
    test "deletes chosen quality_rule", %{conn: conn} do
      quality_rule = insert(:quality_rule)
      conn = delete(conn, rule_implementation_path(conn, :delete, quality_rule))
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent(404, fn ->
        get(conn, rule_implementation_path(conn, :show, quality_rule))
      end)
    end
  end

  describe "get_quality_rules" do
    @tag :admin_authenticated
    test "lists all quality_rules from a quality control", %{conn: conn, swagger_schema: schema} do
      quality_control = insert(:quality_control)
      quality_rule_type = insert(:quality_rule_type)

      creation_attrs =
        Map.from_struct(
          build(
            :quality_rule,
            quality_control_id: quality_control.id,
            quality_rule_type_id: quality_rule_type.id
          )
        )

      conn = post(conn, rule_implementation_path(conn, :create), quality_rule: creation_attrs)
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert response(conn, 201)

      conn = recycle_and_put_headers(conn)

      conn =
        get(conn, rule_rule_implementation_path(conn, :get_quality_rules, quality_control.id))

      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      json_response = List.first(json_response(conn, 200)["data"])

      assert creation_attrs[:quality_control_id] == json_response["quality_control_id"]
      assert creation_attrs[:description] == json_response["description"]
      assert creation_attrs[:system_params] == json_response["system_params"]
      assert creation_attrs[:system] == json_response["system"]
      assert creation_attrs[:type] == json_response["type"]
      assert creation_attrs[:tag] == json_response["tag"]

      conn = recycle_and_put_headers(conn)

      conn =
        get(
          conn,
          rule_rule_implementation_path(conn, :get_quality_rules, @invalid_quality_control_id)
        )

      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      assert json_response(conn, 200)["data"] == []
    end
  end
end
