defmodule TdDqWeb.RuleImplementationControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"
  import TdDq.Factory
  import TdDqWeb.Authentication, only: :functions

  @invalid_rule_id -1

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all rule_implementations", %{conn: conn, swagger_schema: schema} do
      conn = get(conn, rule_implementation_path(conn, :index))
      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      assert json_response(conn, 200)["data"] == []
    end

    @tag :admin_authenticated
    test "lists all rule_implementations filtered by rule business_concept_id and state", %{conn: conn, swagger_schema: schema} do
      rule_type = insert(:rule_type)
      rule1 = insert(:rule, rule_type: rule_type, business_concept_id: "xyz", status: "selectedToExecute")
      rule2 = insert(:rule, rule_type: rule_type)
      insert(:rule_implementation, rule: rule1)
      insert(:rule_implementation, rule: rule1)
      insert(:rule_implementation, rule: rule1)
      insert(:rule_implementation, rule: rule2)

      conn = get(conn, rule_implementation_path(conn, :index), %{"rule_status": "selectedToExecute", "rule_business_concept_id": "xyz"})
      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      assert length(json_response(conn, 200)["data"]) == 3
    end

  end

  describe "create rule_implementation" do
    @tag :admin_authenticated
    test "renders rule_implementation when data is valid", %{conn: conn, swagger_schema: schema} do
      rule = insert(:rule)

      creation_attrs =
        Map.from_struct(
          build(:rule_implementation, rule_id: rule.id)
        )

      conn = post(conn, rule_implementation_path(conn, :create), rule_implementation: creation_attrs)
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, rule_implementation_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      json_response = json_response(conn, 200)["data"]

      assert creation_attrs[:rule_id] == json_response["rule_id"]
      assert creation_attrs[:description] == json_response["description"]
      assert creation_attrs[:system_params] == json_response["system_params"]
      assert creation_attrs[:system] == json_response["system"]
      assert creation_attrs[:tag] == json_response["tag"]
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      rule = insert(:rule)

      creation_attrs =
        Map.from_struct(
          build(:rule_implementation, rule_id: rule.id, name: nil, system: nil)
        )

      conn = post(conn, rule_implementation_path(conn, :create), rule_implementation: creation_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update rule_implementation" do
    @tag :admin_authenticated
    test "renders rule_implementation when data is valid", %{conn: conn, swagger_schema: schema} do
      rule_implementation = insert(:rule_implementation)
      update_attrs = Map.from_struct(rule_implementation)

      update_attrs =
        update_attrs
        |> Map.put(:name, "New name")
        |> Map.put(:system, "New system")
        |> Map.put(:description, "New description")

      conn = put(conn, rule_implementation_path(conn, :update, rule_implementation), rule_implementation: update_attrs)
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert %{"id" => id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, rule_implementation_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      json_response = json_response(conn, 200)["data"]

      assert update_attrs[:rule_id] == json_response["rule_id"]
      assert update_attrs[:description] == json_response["description"]
      assert update_attrs[:system_params] == json_response["system_params"]
      assert update_attrs[:system] == json_response["system"]
      assert update_attrs[:tag] == json_response["tag"]
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      rule_implementation = insert(:rule_implementation)
      update_attrs = Map.from_struct(rule_implementation)

      update_attrs =
        update_attrs
        |> Map.put(:name, nil)
        |> Map.put(:system, nil)

      conn = put(conn, rule_implementation_path(conn, :update, rule_implementation), rule_implementation: update_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete rule_implementation" do
    @tag :admin_authenticated
    test "deletes chosen rule_implementation", %{conn: conn} do
      rule_implementation = insert(:rule_implementation)
      conn = delete(conn, rule_implementation_path(conn, :delete, rule_implementation))
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent(404, fn ->
        get(conn, rule_implementation_path(conn, :show, rule_implementation))
      end)
    end
  end

  describe "get_rule_implementations" do
    @tag :admin_authenticated
    test "lists all rule_implementations from a rule", %{conn: conn, swagger_schema: schema} do
      rule = insert(:rule)

      creation_attrs =
        Map.from_struct(
          build(
            :rule_implementation,
            rule_id: rule.id
          )
        )

      conn = post(conn, rule_implementation_path(conn, :create), rule_implementation: creation_attrs)
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert response(conn, 201)

      conn = recycle_and_put_headers(conn)

      conn =
        get(conn, rule_rule_implementation_path(conn, :get_rule_implementations, rule.id))

      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      json_response = List.first(json_response(conn, 200)["data"])

      assert creation_attrs[:rule_id] == json_response["rule_id"]
      assert creation_attrs[:description] == json_response["description"]
      assert creation_attrs[:system_params] == json_response["system_params"]
      assert creation_attrs[:system] == json_response["system"]
      assert creation_attrs[:tag] == json_response["tag"]

      conn = recycle_and_put_headers(conn)

      conn =
        get(
          conn,
          rule_rule_implementation_path(conn, :get_rule_implementations, @invalid_rule_id)
        )

      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      assert json_response(conn, 200)["data"] == []
    end
  end
end
