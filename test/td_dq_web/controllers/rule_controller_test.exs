defmodule TdDqWeb.RuleControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDq.Rules
  alias TdDq.Rules.Rule
  alias TdDqWeb.ApiServices.MockTdAuditService
  import TdDqWeb.Authentication, only: :functions
  import TdDq.Factory

  setup_all do
    start_supervised MockTdAuditService
    :ok
  end

  @create_fixture_attrs %{business_concept_id: "some business_concept_id",
    description: "some description", goal: 42, minimum: 42, name: "some name",
    population: "some population", priority: "some priority",
    weight: 42, updated_by: Integer.mod(:binary.decode_unsigned("app-admin"), 100_000), principle: %{},
    type_params: %{}}

  @create_attrs %{business_concept_id: "some business_concept_id",
    description: "some description", goal: 42, minimum: 42, name: "some name",
    population: "some population", priority: "some priority", weight: 42, principle: %{},
    type_params: %{}}

  @update_attrs %{business_concept_id: "some updated business_concept_id", description: "some updated description",
    goal: 43, minimum: 43, name: "some updated name", population: "some updated population",
    priority: "some updated priority", weight: 43, principle: %{}}

  @invalid_attrs %{business_concept_id: nil, description: nil, goal: nil, minimum: nil,
    name: nil, population: nil, priority: nil, weight: nil, principle: nil,
    type_params: nil}

  @comparable_fields ["id",
                      "business_concept_id",
                      "description",
                      "goal",
                      "minimum",
                      "name",
                      "population",
                      "priority",
                      "weight",
                      "active",
                      "version",
                      "updated_by",
                      "principle",
                      "rule_type_id",
                      "type_params",
                      "tag"]

  @admin_user_name "app-admin"

  def fixture(:rule) do
    rule_type = insert(:rule_type)
    creation_attrs = @create_fixture_attrs
    |> Map.put(:rule_type_id, rule_type.id)
    {:ok, rule} = Rules.create_rule(rule_type, creation_attrs)
    rule
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "lists all rules", %{conn: conn, swagger_schema: schema} do
      conn = get conn, rule_path(conn, :index)
      validate_resp_schema(conn, schema, "RulesResponse")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "get_rules_by_concept" do
    @tag authenticated_user: @admin_user_name
    test "lists all rules of a concept", %{conn: conn, swagger_schema: schema} do
      conn = get conn, rule_path(conn, :get_rules_by_concept, "id")
      validate_resp_schema(conn, schema, "RulesResponse")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "verify token is required" do
    test "renders unauthenticated when no token", %{conn: conn, swagger_schema: schema} do
      conn = put_req_header(conn, "content-type", "application/json")
      conn = post conn, rule_path(conn, :create), rule: @create_attrs
      validate_resp_schema(conn, schema, "RuleResponse")
      assert conn.status == 401
    end
  end

  describe "verify token secret key must be the one in config" do
    test "renders unauthenticated when passing token signed with invalid secret key", %{conn: conn} do
      #token with secret key SuperSecretTruedat2"
      jwt = "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJ0cnVlQkciLCJleHAiOjE1MTg2MDE2ODMsImlhdCI6MTUxODU5ODA4MywiaXNzIjoidHJ1ZUJHIiwianRpIjoiNTAzNmI5MTQtYmViOC00N2QyLWI4NGQtOTA2ZjMyMTQwMDRhIiwibmJmIjoxNTE4NTk4MDgyLCJzdWIiOiJhcHAtYWRtaW4iLCJ0eXAiOiJhY2Nlc3MifQ.0c_ZpzfiwUeRAbHe-34rvFZNjQoU_0NCMZ-T6r6_DUqPiwlp1H65vY-G1Fs1011ngAAVf3Xf8Vkqp-yOQUDTdw"
      conn = put_auth_headers(conn, jwt)
      conn = post conn, rule_path(conn, :create), rule: @create_attrs
      assert conn.status == 401
    end
  end

  describe "create rule" do
    @tag authenticated_user: @admin_user_name
    test "renders rule when data is valid", %{conn: conn, swagger_schema: schema} do
      rule_type = insert(:rule_type)
      creation_attrs = @create_fixture_attrs
      |> Map.put("rule_type_id", rule_type.id)
      conn = post conn, rule_path(conn, :create), rule: creation_attrs
      validate_resp_schema(conn, schema, "RuleResponse")
      assert %{"id" => id} = json_response(conn, 201)["data"]
      conn = recycle_and_put_headers(conn)
      conn = get conn, rule_path(conn, :show, id)
      validate_resp_schema(conn, schema, "RuleResponse")
      comparable_fields = Map.take(json_response(conn, 200)["data"], @comparable_fields)
      assert comparable_fields == %{
        "id" => id,
        "business_concept_id" => "some business_concept_id",
        "description" => "some description",
        "goal" => 42,
        "minimum" => 42,
        "name" => "some name",
        "population" => "some population",
        "priority" => "some priority",
        "weight" => 42,
        "active" => false,
        "version" => 1,
        "updated_by" => @create_fixture_attrs.updated_by,
        "principle" => %{},
        "rule_type_id" => rule_type.id,
        "type_params" => %{},
        "tag" => %{}
      }
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn, swagger_schema: schema} do
      conn = post conn, rule_path(conn, :create), rule: @invalid_attrs
      validate_resp_schema(conn, schema, "RuleResponse")
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update rule" do
    setup [:create_rule]

    @tag authenticated_user: @admin_user_name
    test "renders rule when data is valid", %{conn: conn, rule: %Rule{id: id} = rule, swagger_schema: schema} do
      conn = put conn, rule_path(conn, :update, rule), rule: @update_attrs
      validate_resp_schema(conn, schema, "RuleResponse")
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)
      conn = get conn, rule_path(conn, :show, id)
      validate_resp_schema(conn, schema, "RuleResponse")
      comparable_fields = Map.take(json_response(conn, 200)["data"], @comparable_fields)

      assert comparable_fields == %{
        "id" => id,
        "business_concept_id" => "some updated business_concept_id",
        "description" => "some updated description",
        "goal" => 43,
        "minimum" => 43,
        "name" => "some updated name",
        "population" => "some updated population",
        "priority" => "some updated priority",
        "weight" => 43,
        "active" => false,
        "version" => 1,
        "updated_by" => @create_fixture_attrs.updated_by,
        "principle" => %{},
        "rule_type_id" => rule.rule_type_id,
        "type_params" => %{},
        "tag" => %{}
      }
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn, rule: rule, swagger_schema: schema} do
      conn = put conn, rule_path(conn, :update, rule), rule: @invalid_attrs
      validate_resp_schema(conn, schema, "RuleResponse")
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete rule" do
    setup [:create_rule]

    @tag authenticated_user: @admin_user_name
    test "deletes chosen rule", %{conn: conn, rule: rule} do
      conn = delete conn, rule_path(conn, :delete, rule)
      assert response(conn, 204)
      conn = recycle_and_put_headers(conn)
      assert_error_sent 404, fn ->
        get conn, rule_path(conn, :show, rule)
      end
    end
  end

  defp create_rule(_) do
    rule = fixture(:rule)
    {:ok, rule: rule}
  end
end
