defmodule TdDqWeb.RuleControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDq.MockRelationCache
  alias TdDq.Permissions.MockPermissionResolver
  alias TdDq.Rules
  alias TdDq.Rules.Rule
  alias TdDqWeb.ApiServices.MockTdAuditService
  import TdDqWeb.Authentication, only: :functions
  import TdDq.Factory

  setup_all do
    start_supervised(MockTdAuditService)
    start_supervised(MockRelationCache)
    start_supervised(MockPermissionResolver)
    :ok
  end

  @create_fixture_attrs %{
    business_concept_id: "some business_concept_id",
    description: "some description",
    goal: 42,
    minimum: 42,
    name: "some name",
    population: "some population",
    priority: "some priority",
    weight: 42,
    updated_by: Integer.mod(:binary.decode_unsigned("app-admin"), 100_000),
    type_params: %{}
  }

  @create_fixture_attrs_no_bc %{
    description: "some description",
    goal: 42,
    minimum: 42,
    name: "some name",
    population: "some population",
    priority: "some priority",
    weight: 42,
    updated_by: Integer.mod(:binary.decode_unsigned("app-admin"), 100_000),
    type_params: %{}
  }

  @create_attrs %{
    business_concept_id: "some business_concept_id",
    description: "some description",
    goal: 42,
    minimum: 42,
    name: "some name",
    population: "some population",
    priority: "some priority",
    weight: 42,
    type_params: %{}
  }

  @update_attrs %{
    business_concept_id: "some updated business_concept_id",
    description: "some updated description",
    goal: 43,
    minimum: 43,
    name: "some updated name",
    population: "some updated population",
    priority: "some updated priority",
    weight: 43
  }

  @invalid_attrs %{
    business_concept_id: nil,
    description: nil,
    goal: nil,
    minimum: nil,
    name: nil,
    population: nil,
    priority: nil,
    weight: nil,
    type_params: nil
  }

  @comparable_fields [
    "id",
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
    "rule_type_id",
    "type_params"
  ]

  @admin_user_name "app-admin"
  @user_name "Im not an admon"

  @list_cache [
    %{
      resource_id: 1,
      relation_type: "business_concept_to_field",
      context: %{
        "system" => "system_1",
        "structure" => "structure_1",
        "structure_id" => "1",
        "group" => "group_1",
        "field" => "field_1"
      },
      resource_type: "data_field"
    },
    %{
      resource_id: 2,
      relation_type: "business_concept_to_field",
      context: %{
        "system" => "system_2",
        "structure" => "structure_2",
        "structure_id" => "2",
        "group" => "group_2",
        "field" => "field_2"
      },
      resource_type: "data_field"
    },
    %{
      resource_id: 3,
      relation_type: "business_concept_to_field",
      context: %{
        "system" => "system_3",
        "structure" => "structure_3",
        "structure_id" => "3",
        "group" => "group_3",
        "field" => "field_3"
      },
      resource_type: "data_field"
    }
  ]

  def fixture(:rule) do
    rule_type = insert(:rule_type)

    creation_attrs =
      @create_fixture_attrs
      |> Map.put(:rule_type_id, rule_type.id)

    {:ok, rule} = Rules.create_rule(rule_type, creation_attrs)
    rule
  end

  defp cache_fixture(resources_list) do
    resources_list |> Enum.map(&MockRelationCache.put_relation(&1))
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "lists all rules", %{conn: conn, swagger_schema: schema} do
      conn = get(conn, Routes.rule_path(conn, :index))
      validate_resp_schema(conn, schema, "RulesResponse")
      assert json_response(conn, 200)["data"] == []
    end

    @tag authenticated_no_admin_user: @user_name
    test "lists all rules depending on permissions", %{
      conn: conn,
      user: %{id: user_id},
      swagger_schema: schema
    } do
      rule_type = insert(:rule_type)
      business_concept_id_permission = "1"
      domain_id_with_permission = 1

      creation_attrs_1 = %{
        business_concept_id: business_concept_id_permission,
        description: "some description",
        goal: 42,
        minimum: 42,
        name: "some name 1",
        population: "some population",
        priority: "some priority",
        weight: 42,
        updated_by: Integer.mod(:binary.decode_unsigned("app-admin"), 100_000),
        type_params: %{},
        rule_type_id: rule_type.id
      }

      creation_attrs_2 = %{
        business_concept_id: "2",
        description: "some description",
        goal: 42,
        minimum: 42,
        name: "some name 2",
        population: "some population",
        priority: "some priority",
        weight: 42,
        updated_by: Integer.mod(:binary.decode_unsigned("app-admin"), 100_000),
        type_params: %{},
        rule_type_id: rule_type.id
      }

      {:ok, rule} = Rules.create_rule(rule_type, creation_attrs_1)
      Rules.create_rule(rule_type, creation_attrs_2)

      create_acl_entry(
        user_id,
        business_concept_id_permission,
        domain_id_with_permission,
        [domain_id_with_permission],
        "watch"
      )

      conn = get(conn, Routes.rule_path(conn, :index))
      validate_resp_schema(conn, schema, "RulesResponse")

      assert Enum.all?(json_response(conn, 200)["data"], fn %{"id" => id} -> id == rule.id end)
    end
  end

  describe "get_rules_by_concept" do
    @tag authenticated_user: @admin_user_name
    test "lists all rules of a concept", %{conn: conn, swagger_schema: schema} do
      conn = get(conn, Routes.rule_path(conn, :get_rules_by_concept, "id"))
      validate_resp_schema(conn, schema, "RulesResponse")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "verify token is required" do
    test "renders unauthenticated when no token", %{conn: conn, swagger_schema: schema} do
      conn = put_req_header(conn, "content-type", "application/json")
      conn = post(conn, Routes.rule_path(conn, :create), rule: @create_attrs)
      validate_resp_schema(conn, schema, "RuleResponse")
      assert conn.status == 401
    end
  end

  describe "verify token secret key must be the one in config" do
    test "renders unauthenticated when passing token signed with invalid secret key", %{
      conn: conn
    } do
      # token with secret key SuperSecretTruedat2"
      jwt =
        "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJ0cnVlQkciLCJleHAiOjE1MTg2MDE2ODMsImlhdCI6MTUxODU5ODA4MywiaXNzIjoidHJ1ZUJHIiwianRpIjoiNTAzNmI5MTQtYmViOC00N2QyLWI4NGQtOTA2ZjMyMTQwMDRhIiwibmJmIjoxNTE4NTk4MDgyLCJzdWIiOiJhcHAtYWRtaW4iLCJ0eXAiOiJhY2Nlc3MifQ.0c_ZpzfiwUeRAbHe-34rvFZNjQoU_0NCMZ-T6r6_DUqPiwlp1H65vY-G1Fs1011ngAAVf3Xf8Vkqp-yOQUDTdw"

      conn = put_auth_headers(conn, jwt)
      conn = post(conn, Routes.rule_path(conn, :create), rule: @create_attrs)
      assert conn.status == 401
    end
  end

  describe "create rule" do
    @tag authenticated_user: @admin_user_name
    test "renders rule when data is valid", %{conn: conn, swagger_schema: schema} do
      rule_type = insert(:rule_type)

      creation_attrs =
        @create_fixture_attrs
        |> Map.put("rule_type_id", rule_type.id)

      conn = post(conn, Routes.rule_path(conn, :create), rule: creation_attrs)
      validate_resp_schema(conn, schema, "RuleResponse")
      assert %{"id" => id} = json_response(conn, 201)["data"]
      conn = recycle_and_put_headers(conn)
      conn = get(conn, Routes.rule_path(conn, :show, id))
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
               "rule_type_id" => rule_type.id,
               "type_params" => %{}
             }
    end

    @tag authenticated_user: @admin_user_name
    test "renders rule when data is valid without business concept", %{
      conn: conn,
      swagger_schema: schema
    } do
      rule_type = insert(:rule_type)

      creation_attrs =
        @create_fixture_attrs_no_bc
        |> Map.put("rule_type_id", rule_type.id)

      conn = post(conn, Routes.rule_path(conn, :create), rule: creation_attrs)
      validate_resp_schema(conn, schema, "RuleResponse")
      assert %{"id" => id} = json_response(conn, 201)["data"]
      conn = recycle_and_put_headers(conn)
      conn = get(conn, Routes.rule_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleResponse")
      comparable_fields = Map.take(json_response(conn, 200)["data"], @comparable_fields)

      assert comparable_fields == %{
               "id" => id,
               "business_concept_id" => nil,
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
               "rule_type_id" => rule_type.id,
               "type_params" => %{}
             }
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn, swagger_schema: schema} do
      conn = post(conn, Routes.rule_path(conn, :create), rule: @invalid_attrs)
      validate_resp_schema(conn, schema, "RuleResponse")
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "get_rule_detail" do
    @tag authenticated_user: @user_name
    test "renders rule when data is valid", %{
      conn: conn,
      swagger_schema: schema,
      user: %{id: user_id}
    } do
      cache_fixture(@list_cache)

      rule_type =
        insert(
          :rule_type,
          params: %{"system_params" => [%{"name" => "table", "type" => "string"}]}
        )

      business_concept_id_permission = "1"
      domain_id_with_permission = "1"

      create_acl_entry(
        user_id,
        business_concept_id_permission,
        domain_id_with_permission,
        [domain_id_with_permission],
        "create"
      )

      creation_attrs =
        @create_fixture_attrs
        |> Map.put("rule_type_id", rule_type.id)
        |> Map.put("business_concept_id", business_concept_id_permission)

      conn = post(conn, Routes.rule_path(conn, :create), rule: creation_attrs)
      validate_resp_schema(conn, schema, "RuleResponse")

      assert %{"id" => id} = json_response(conn, 201)["data"]
      conn = recycle_and_put_headers(conn)

      conn =
        get(
          conn,
          Routes.rule_rule_path(conn, :get_rule_detail, id)
        )

      validate_resp_schema(conn, schema, "RuleDetailResponse")
      %{"system_values" => system_values} = json_response(conn, 200)["data"]

      system_params_in_response = system_values |> Map.get("system", [])

      system_params_in_resource_list =
        @list_cache |> Enum.map(&(&1 |> Map.get(:context) |> Map.get("system")))

      assert system_params_in_response
             |> Enum.all?(fn %{"name" => name} ->
               Enum.member?(system_params_in_resource_list, name)
             end)
    end
  end

  describe "update rule" do
    setup [:create_rule]

    @tag authenticated_user: @admin_user_name
    test "renders rule when data is valid", %{
      conn: conn,
      rule: %Rule{id: id} = rule,
      swagger_schema: schema
    } do
      conn = put(conn, Routes.rule_path(conn, :update, rule), rule: @update_attrs)
      validate_resp_schema(conn, schema, "RuleResponse")
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)
      conn = get(conn, Routes.rule_path(conn, :show, id))
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
               "rule_type_id" => rule.rule_type_id,
               "type_params" => %{}
             }
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn, rule: rule, swagger_schema: schema} do
      conn = put(conn, Routes.rule_path(conn, :update, rule), rule: @invalid_attrs)
      validate_resp_schema(conn, schema, "RuleResponse")
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete rule" do
    setup [:create_rule]

    @tag authenticated_user: @admin_user_name
    test "deletes chosen rule", %{conn: conn, rule: rule} do
      conn = delete(conn, Routes.rule_path(conn, :delete, rule))
      assert response(conn, 204)
      conn = recycle_and_put_headers(conn)

      assert_error_sent(404, fn ->
        get(conn, Routes.rule_path(conn, :show, rule))
      end)
    end
  end

  defp create_acl_entry(user_id, bc_id, domain_id, domain_ids, role) do
    MockPermissionResolver.create_hierarchy(bc_id, domain_ids)

    MockPermissionResolver.create_acl_entry(%{
      principal_id: user_id,
      principal_type: "user",
      resource_id: domain_id,
      resource_type: "domain",
      role_name: role
    })
  end

  defp create_rule(_) do
    rule = fixture(:rule)
    {:ok, rule: rule}
  end
end
