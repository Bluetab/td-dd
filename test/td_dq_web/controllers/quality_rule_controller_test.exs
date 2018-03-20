defmodule TdDqWeb.QualityRuleControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"
  import TdDq.Factory
  import TdDqWeb.Authentication, only: :functions

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all quality_rules", %{conn: conn, swagger_schema: schema} do
      conn = get conn, quality_rule_path(conn, :index)
      validate_resp_schema(conn, schema, "QualityRulesResponse")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create quality_rule" do
    @tag :admin_authenticated
    test "renders quality_rule when data is valid", %{conn: conn, swagger_schema: schema} do
      quality_control = insert(:quality_control)
      creation_attrs = Map.from_struct(build(:quality_rule, quality_control_id: quality_control.id))

      conn = post conn, quality_rule_path(conn, :create), quality_rule: creation_attrs
      validate_resp_schema(conn, schema, "QualityRuleResponse")
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get conn, quality_rule_path(conn, :show, id)
      validate_resp_schema(conn, schema, "QualityRuleResponse")
      json_response = json_response(conn, 200)["data"]

      assert creation_attrs[:quality_control_id] == json_response["quality_control_id"]
      assert creation_attrs[:description] == json_response["description"]
      assert creation_attrs[:parameters] == json_response["parameters"]
      assert creation_attrs[:system] == json_response["system"]
      assert creation_attrs[:type] == json_response["type"]
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      quality_control = insert(:quality_control)
      creation_attrs = Map.from_struct(build(:quality_rule, quality_control_id: quality_control.id, name: nil, system: nil))
      conn = post conn, quality_rule_path(conn, :create), quality_rule: creation_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update quality_rule" do

    @tag :admin_authenticated
    test "renders quality_rule when data is valid", %{conn: conn, swagger_schema: schema} do
      quality_rule = insert(:quality_rule)
      update_attrs = Map.from_struct(quality_rule)
      update_attrs = update_attrs
      |> Map.put(:name, "New name")
      |> Map.put(:system, "New system")
      |> Map.put(:description, "New description")

      conn = put conn, quality_rule_path(conn, :update, quality_rule), quality_rule: update_attrs
      validate_resp_schema(conn, schema, "QualityRuleResponse")
      assert %{"id" => id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get conn, quality_rule_path(conn, :show, id)
      validate_resp_schema(conn, schema, "QualityRuleResponse")
      json_response = json_response(conn, 200)["data"]

      assert update_attrs[:quality_control_id] == json_response["quality_control_id"]
      assert update_attrs[:description] == json_response["description"]
      assert update_attrs[:parameters] == json_response["parameters"]
      assert update_attrs[:system] == json_response["system"]
      assert update_attrs[:type] == json_response["type"]
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      quality_rule = insert(:quality_rule)
      update_attrs = Map.from_struct(quality_rule)
      update_attrs = update_attrs
      |> Map.put(:name, nil)
      |> Map.put(:system, nil)
      conn = put conn, quality_rule_path(conn, :update, quality_rule), quality_rule: update_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete quality_rule" do

    @tag :admin_authenticated
    test "deletes chosen quality_rule", %{conn: conn} do
      quality_rule = insert(:quality_rule)
      conn = delete conn, quality_rule_path(conn, :delete, quality_rule)
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent 404, fn ->
        get conn, quality_rule_path(conn, :show, quality_rule)
      end
    end
  end
end
