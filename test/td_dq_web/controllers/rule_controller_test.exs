defmodule TdDqWeb.RuleControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import TdDqWeb.Authentication, only: :functions
  import TdDq.Factory

  alias TdDq.Cache.RuleLoader
  alias TdDq.MockRelationCache
  alias TdDq.Permissions.MockPermissionResolver
  alias TdDq.Rules
  alias TdDq.Rules.Rule
  alias TdDq.Search.IndexWorker
  alias TdDqWeb.ApiServices.MockTdAuditService

  setup_all do
    start_supervised(MockTdAuditService)
    start_supervised(MockRelationCache)
    start_supervised(MockPermissionResolver)
    start_supervised(IndexWorker)
    start_supervised(RuleLoader)
    :ok
  end

  @create_fixture_attrs %{
    business_concept_id: "some business_concept_id",
    description: %{"document" => "some description"},
    goal: 42,
    minimum: 42,
    name: "some name",
    updated_by: Integer.mod(:binary.decode_unsigned("app-admin"), 100_000),
    type_params: %{}
  }

  @create_fixture_attrs_no_bc %{
    description: %{"document" => "some description"},
    goal: 42,
    minimum: 42,
    name: "some name",
    updated_by: Integer.mod(:binary.decode_unsigned("app-admin"), 100_000),
    type_params: %{}
  }

  @create_attrs %{
    business_concept_id: "some business_concept_id",
    description: %{"document" => "some description"},
    goal: 42,
    minimum: 42,
    name: "some name",
    type_params: %{}
  }

  @update_attrs %{
    business_concept_id: "some updated business_concept_id",
    description: %{"document" => "some updated description"},
    goal: 43,
    minimum: 43,
    name: "some updated name"
  }

  @invalid_attrs %{
    business_concept_id: nil,
    description: nil,
    goal: nil,
    minimum: nil,
    name: nil,
    type_params: nil
  }

  @comparable_fields [
    "id",
    "business_concept_id",
    "description",
    "goal",
    "minimum",
    "name",
    "active",
    "version",
    "updated_by",
    "rule_type_id",
    "type_params"
  ]

  @user_name "Im not an admin"

  def fixture(:rule) do
    {:ok, rule} = Rules.create_rule(@create_fixture_attrs)
    rule
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all rules", %{conn: conn, swagger_schema: schema} do
      conn = get(conn, Routes.rule_path(conn, :index))
      validate_resp_schema(conn, schema, "RulesResponse")
      assert json_response(conn, :ok)["data"] == []
    end

    @tag authenticated_no_admin_user: @user_name
    test "lists all rules depending on permissions", %{
      conn: conn,
      user: %{id: user_id},
      swagger_schema: schema
    } do
      business_concept_id_permission = "1"
      domain_id_with_permission = 1

      creation_attrs_1 = %{
        business_concept_id: business_concept_id_permission,
        description: %{"document" => "some description"},
        goal: 42,
        minimum: 42,
        name: "some name 1",
        updated_by: Integer.mod(:binary.decode_unsigned("app-admin"), 100_000)
      }

      creation_attrs_2 = %{
        business_concept_id: "2",
        description: %{"document" => "some description"},
        goal: 42,
        minimum: 42,
        name: "some name 2",
        updated_by: Integer.mod(:binary.decode_unsigned("app-admin"), 100_000)
      }

      {:ok, rule} = Rules.create_rule(creation_attrs_1)
      Rules.create_rule(creation_attrs_2)

      create_acl_entry(
        user_id,
        business_concept_id_permission,
        domain_id_with_permission,
        [domain_id_with_permission],
        "watch"
      )

      conn = get(conn, Routes.rule_path(conn, :index))
      validate_resp_schema(conn, schema, "RulesResponse")

      assert Enum.all?(json_response(conn, :ok)["data"], fn %{"id" => id} -> id == rule.id end)
    end
  end

  describe "get_rules_by_concept" do
    @tag :admin_authenticated
    test "lists all rules of a concept", %{conn: conn, swagger_schema: schema} do
      conn = get(conn, Routes.rule_path(conn, :get_rules_by_concept, "id"))
      validate_resp_schema(conn, schema, "RulesResponse")
      assert json_response(conn, :ok)["data"] == []
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
    @tag :admin_authenticated
    test "renders rule when data is valid", %{conn: conn, swagger_schema: schema} do
      creation_attrs = @create_fixture_attrs

      conn = post(conn, Routes.rule_path(conn, :create), rule: creation_attrs)
      validate_resp_schema(conn, schema, "RuleResponse")
      assert %{"id" => id} = json_response(conn, 201)["data"]
      conn = recycle_and_put_headers(conn)
      conn = get(conn, Routes.rule_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleResponse")
      comparable_fields = Map.take(json_response(conn, :ok)["data"], @comparable_fields)

      assert comparable_fields == %{
               "id" => id,
               "business_concept_id" => "some business_concept_id",
               "description" => %{"document" => "some description"},
               "goal" => 42,
               "minimum" => 42,
               "name" => "some name",
               "active" => false,
               "version" => 1,
               "updated_by" => @create_fixture_attrs.updated_by
             }
    end

    @tag :admin_authenticated
    test "renders rule when data is valid without business concept", %{
      conn: conn,
      swagger_schema: schema
    } do
      conn = post(conn, Routes.rule_path(conn, :create), rule: @create_fixture_attrs_no_bc)
      validate_resp_schema(conn, schema, "RuleResponse")
      assert %{"id" => id} = json_response(conn, 201)["data"]
      conn = recycle_and_put_headers(conn)
      conn = get(conn, Routes.rule_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleResponse")
      comparable_fields = Map.take(json_response(conn, :ok)["data"], @comparable_fields)

      assert comparable_fields == %{
               "id" => id,
               "business_concept_id" => nil,
               "description" => %{"document" => "some description"},
               "goal" => 42,
               "minimum" => 42,
               "name" => "some name",
               "active" => false,
               "version" => 1,
               "updated_by" => @create_fixture_attrs.updated_by
             }
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      assert %{"errors" => _errors} =
               conn
               |> post(Routes.rule_path(conn, :create), rule: @invalid_attrs)
               |> json_response(:unprocessable_entity)
    end

    @tag :admin_authenticated
    test "renders errors when rule result type is numeric and goal is higher than minimum", %{
      conn: conn
    } do
      creation_attrs =
        Map.merge(
          @create_fixture_attrs_no_bc,
          %{result_type: "errors_number", minimum: 5, goal: 10}
        )

      assert %{"errors" => errors} =
               conn
               |> post(Routes.rule_path(conn, :create), rule: creation_attrs)
               |> json_response(:unprocessable_entity)

      assert errors == [
               %{
                 "code" => "undefined",
                 "name" => "rule.error.minimum.must.be.greater.than.or.equal.to.goal"
               }
             ]
    end

    @tag :admin_authenticated
    test "renders errors when rule result type is percentage and goal is lower than minimum", %{
      conn: conn
    } do
      creation_attrs =
        Map.merge(
          @create_fixture_attrs_no_bc,
          %{result_type: "percentage", minimum: 50, goal: 10}
        )

      assert %{"errors" => errors} =
               conn
               |> post(Routes.rule_path(conn, :create), rule: creation_attrs)
               |> json_response(:unprocessable_entity)

      assert errors == [
               %{
                 "code" => "undefined",
                 "name" => "rule.error.goal.must.be.greater.than.or.equal.to.minimum"
               }
             ]
    end
  end

  describe "update rule" do
    setup [:create_rule]

    @tag :admin_authenticated
    test "renders rule when data is valid", %{
      conn: conn,
      rule: %Rule{id: id} = rule,
      swagger_schema: schema
    } do
      conn = put(conn, Routes.rule_path(conn, :update, rule), rule: @update_attrs)
      validate_resp_schema(conn, schema, "RuleResponse")
      assert %{"id" => ^id} = json_response(conn, :ok)["data"]

      conn = recycle_and_put_headers(conn)
      conn = get(conn, Routes.rule_path(conn, :show, id))
      validate_resp_schema(conn, schema, "RuleResponse")
      comparable_fields = Map.take(json_response(conn, :ok)["data"], @comparable_fields)

      assert comparable_fields == %{
               "id" => id,
               "business_concept_id" => "some updated business_concept_id",
               "description" => %{"document" => "some updated description"},
               "goal" => 43,
               "minimum" => 43,
               "name" => "some updated name",
               "active" => false,
               "version" => 1,
               "updated_by" => @create_fixture_attrs.updated_by
             }
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn, rule: rule, swagger_schema: schema} do
      conn = put(conn, Routes.rule_path(conn, :update, rule), rule: @invalid_attrs)
      validate_resp_schema(conn, schema, "RuleResponse")
      assert json_response(conn, :unprocessable_entity)["errors"] != %{}
    end
  end

  describe "delete rule" do
    setup [:create_rule]

    @tag :admin_authenticated
    test "deletes chosen rule", %{conn: conn, rule: rule} do
      assert conn
             |> delete(Routes.rule_path(conn, :delete, rule))
             |> response(:no_content)

      assert_error_sent(:not_found, fn ->
        get(conn, Routes.rule_path(conn, :show, rule))
      end)
    end
  end

  describe "execute_rule" do
    setup [:create_rule]

    @tag :admin_authenticated
    test "execute rules as admin and true execution filter", %{
      conn: conn,
      rule: rule,
      swagger_schema: schema
    } do
      params = %{"search_params" => %{"filters" => %{"execution.raw" => [true]}}}

      assert %{"data" => data} =
               conn
               |> post(Routes.rule_path(conn, :execute_rules), params)
               |> validate_resp_schema(schema, "RulesExecuteResponse")
               |> json_response(:ok)

      assert data == [rule.id]
    end

    @tag :admin_authenticated
    test "execute rules as admin and false execution filter", %{
      conn: conn,
      rule: rule,
      swagger_schema: schema
    } do
      params = %{"search_params" => %{"filters" => %{"execution.raw" => [false]}}}

      assert %{"data" => data} =
               conn
               |> post(Routes.rule_path(conn, :execute_rules), params)
               |> validate_resp_schema(schema, "RulesExecuteResponse")
               |> json_response(:ok)

      assert data == [rule.id]
    end

    @tag :admin_authenticated
    test "execute rules as admin and no execution filter", %{
      conn: conn,
      rule: rule,
      swagger_schema: schema
    } do
      params = %{"search_params" => %{"filters" => %{}}}

      assert %{"data" => data} =
               conn
               |> post(Routes.rule_path(conn, :execute_rules), params)
               |> validate_resp_schema(schema, "RulesExecuteResponse")
               |> json_response(:ok)

      assert data == [rule.id]
    end

    @tag :admin_authenticated
    test "execute rules as admin with rule_ids filter", %{
      conn: conn,
      rule: rule,
      swagger_schema: schema
    } do
      %{id: id} = insert(:rule)

      params = %{"search_params" => %{"rule_ids" => [rule.id, id]}}

      assert %{"data" => data} =
               conn
               |> post(Routes.rule_path(conn, :execute_rules), params)
               |> validate_resp_schema(schema, "RulesExecuteResponse")
               |> json_response(:ok)

      assert data == [rule.id, id]
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
