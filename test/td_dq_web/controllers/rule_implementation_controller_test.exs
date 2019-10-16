defmodule TdDqWeb.RuleImplementationControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"
  import TdDq.Factory
  import TdDqWeb.Authentication, only: :functions
  alias TdDq.Cache.RuleLoader
  alias TdDq.Search.IndexWorker

  @invalid_rule_id -1

  setup_all do
    start_supervised(IndexWorker)
    start_supervised(RuleLoader)
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all rule_implementations", %{conn: conn, swagger_schema: schema} do
      conn = get(conn, Routes.rule_implementation_path(conn, :index))
      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      assert json_response(conn, 200)["data"] == []
    end

    @tag :admin_authenticated
    test "lists all rule_implementations filtered by rule business_concept_id and state", %{
      conn: conn,
      swagger_schema: schema
    } do
      rule_type = insert(:rule_type)
      rule1 = insert(:rule, rule_type: rule_type, business_concept_id: "xyz", active: true)
      rule2 = insert(:rule, rule_type: rule_type)
      insert(:rule_implementation, implementation_key: "ri1", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri2", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri3", rule: rule1)
      insert(:rule_implementation, implementation_key: "ri4", rule: rule2)

      conn =
        get(conn, Routes.rule_implementation_path(conn, :index), %{
          is_rule_active: true,
          rule_business_concept_id: "xyz"
        })

      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      assert length(json_response(conn, 200)["data"]) == 3
    end
  end

  describe "create rule_implementation" do
    @tag :admin_authenticated
    test "renders rule_implementation when data is valid", %{conn: conn, swagger_schema: schema} do
      rule = insert(:rule)

      creation_attrs = Map.from_struct(build(:rule_implementation, rule_id: rule.id))

      conn =
        post(conn, Routes.rule_implementation_path(conn, :create),
          rule_implementation: creation_attrs
        )

      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.rule_implementation_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      json_response = json_response(conn, 200)["data"]

      assert creation_attrs[:rule_id] == json_response["rule_id"]
      assert creation_attrs[:system_params] == json_response["system_params"]
      assert creation_attrs[:system] == json_response["system"]
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      rule = insert(:rule)

      creation_attrs =
        Map.from_struct(
          build(:rule_implementation, rule_id: rule.id, implementation_key: nil, system: nil)
        )

      conn =
        post(conn, Routes.rule_implementation_path(conn, :create),
          rule_implementation: creation_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end

    @tag :admin_authenticated
    test "renders created when rule type does not require system and it is not passed in rule implementation ",
         %{conn: conn} do
      rule_type = insert(:structure_rule_type)
      rule = insert(:rule, rule_type: rule_type, active: true)

      creation_attrs =
        Map.from_struct(
          build(:rule_implementation, rule_id: rule.id, implementation_key: "", system: nil)
        )

      conn =
        post(conn, Routes.rule_implementation_path(conn, :create),
          rule_implementation: creation_attrs
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]
    end

    @tag :admin_authenticated
    test "renders errors when rule requires system and it is not passed in rule implementation ",
         %{conn: conn} do
      rule_type = insert(:rule_type)
      rule = insert(:rule, rule_type: rule_type, active: true)

      creation_attrs =
        Map.from_struct(
          build(:rule_implementation, rule_id: rule.id, implementation_key: "", system: nil)
        )

      conn =
        post(conn, Routes.rule_implementation_path(conn, :create),
          rule_implementation: creation_attrs
        )

      assert json_response(conn, 422) == %{
               "errors" => [
                 %{
                   "code" => "undefined",
                   "name" => "rule.implementation.error.system.required"
                 }
               ]
             }
    end
  end

  describe "update rule_implementation" do
    @tag :admin_authenticated
    test "renders rule_implementation when data is valid", %{conn: conn, swagger_schema: schema} do
      rule_implementation = insert(:rule_implementation)
      update_attrs = Map.from_struct(rule_implementation)

      update_attrs =
        update_attrs
        |> Map.put(:implementation_key, "New implementation key")
        |> Map.put(:system, "New system")

      conn =
        put(conn, Routes.rule_implementation_path(conn, :update, rule_implementation),
          rule_implementation: update_attrs
        )

      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert %{"id" => id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, Routes.rule_implementation_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      json_response = json_response(conn, 200)["data"]

      assert update_attrs[:rule_id] == json_response["rule_id"]
      assert update_attrs[:system_params] == json_response["system_params"]
      assert update_attrs[:system] == json_response["system"]
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      rule_implementation = insert(:rule_implementation)
      update_attrs = Map.from_struct(rule_implementation)

      update_attrs =
        update_attrs
        |> Map.put(:implementation_key, nil)
        |> Map.put(:system, nil)

      conn =
        put(conn, Routes.rule_implementation_path(conn, :update, rule_implementation),
          rule_implementation: update_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete rule_implementation" do
    @tag :admin_authenticated
    test "deletes chosen rule_implementation", %{conn: conn} do
      rule_implementation = insert(:rule_implementation)
      conn = delete(conn, Routes.rule_implementation_path(conn, :delete, rule_implementation))
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent(404, fn ->
        get(conn, Routes.rule_implementation_path(conn, :show, rule_implementation))
      end)
    end
  end

  describe "search_rule_implementations" do
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

      conn =
        post(conn, Routes.rule_implementation_path(conn, :create),
          rule_implementation: creation_attrs
        )

      validate_resp_schema(conn, schema, "RuleImplementationResponse")
      assert response(conn, 201)

      conn = recycle_and_put_headers(conn)

      conn =
        post(conn, Routes.rule_rule_implementation_path(conn, :search_rule_implementations, rule.id))

      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      json_response = List.first(json_response(conn, 200)["data"])

      assert creation_attrs[:rule_id] == json_response["rule_id"]
      assert creation_attrs[:system_params] == json_response["system_params"]
      assert creation_attrs[:system] == json_response["system"]

      conn = recycle_and_put_headers(conn)

      conn =
        post(
          conn,
          Routes.rule_rule_implementation_path(conn, :search_rule_implementations, @invalid_rule_id)
        )

      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      assert json_response(conn, 200)["data"] == []
    end

    @tag :admin_authenticated
    test "lists all deleted rule_implementations of a rule", %{conn: conn, swagger_schema: schema} do
      rule = insert(:rule)
      rule_implementation = insert(:rule_implementation, rule: rule, deleted_at: DateTime.utc_now())
      conn =
        post(conn, Routes.rule_rule_implementation_path(conn, :search_rule_implementations, rule.id, %{"status" => "deleted"}))

      validate_resp_schema(conn, schema, "RuleImplementationsResponse")
      json_response = List.first(json_response(conn, 200)["data"])

      assert Map.get(rule_implementation, :rule_id) == json_response["rule_id"]
      assert Map.get(rule_implementation, :system_params) == json_response["system_params"]
      assert Map.get(rule_implementation, :system) == json_response["system"]
    end
  end
end
