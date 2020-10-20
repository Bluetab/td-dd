defmodule TdDqWeb.RuleControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.{Audit, Redix}
  alias TdDq.Cache.RuleLoader
  alias TdDq.MockRelationCache
  alias TdDq.Permissions.MockPermissionResolver
  alias TdDq.Rules
  alias TdDq.Rules.Rule
  alias TdDq.Search.IndexWorker

  setup_all do
    start_supervised(MockRelationCache)
    start_supervised(MockPermissionResolver)
    start_supervised(IndexWorker)
    start_supervised(RuleLoader)
    :ok
  end

  @user_name "Im not an admin"

  setup %{conn: conn} do
    on_exit(fn -> Redix.del!(Audit.stream()) end)

    [
      conn: put_req_header(conn, "accept", "application/json"),
      rule: insert(:rule)
    ]
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all rules", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => [_rule]} =
               conn
               |> get(Routes.rule_path(conn, :index))
               |> validate_resp_schema(schema, "RulesResponse")
               |> json_response(:ok)
    end

    @tag authenticated_no_admin_user: @user_name
    test "lists all rules depending on permissions", %{
      conn: conn,
      user: %{id: user_id},
      swagger_schema: schema
    } do
      user = build(:user, user_name: @user_name)
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

      {:ok, %{rule: rule}} = Rules.create_rule(creation_attrs_1, user)
      Rules.create_rule(creation_attrs_2, user)

      create_acl_entry(
        user_id,
        business_concept_id_permission,
        domain_id_with_permission,
        [domain_id_with_permission],
        "watch"
      )

      assert %{"data" => data} =
               conn
               |> get(Routes.rule_path(conn, :index))
               |> validate_resp_schema(schema, "RulesResponse")
               |> json_response(:ok)

      assert Enum.all?(data, fn %{"id" => id} -> id == rule.id end)
    end
  end

  describe "get_rules_by_concept" do
    @tag :admin_authenticated
    test "lists all rules of a concept", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => []} =
               conn
               |> get(Routes.rule_path(conn, :get_rules_by_concept, "id"))
               |> validate_resp_schema(schema, "RulesResponse")
               |> json_response(:ok)
    end
  end

  describe "verify token is required" do
    test "renders unauthenticated when no token", %{conn: conn} do
      params = string_params_for(:rule)

      assert conn
             |> put_req_header("content-type", "application/json")
             |> post(Routes.rule_path(conn, :create), rule: params)
             |> response(:unauthorized)
    end
  end

  describe "create rule" do
    @tag :admin_authenticated
    test "renders rule when data is valid", %{conn: conn, swagger_schema: schema} do
      params = string_params_for(:rule)

      assert %{"data" => data} =
               conn
               |> post(Routes.rule_path(conn, :create), rule: params)
               |> validate_resp_schema(schema, "RuleResponse")
               |> json_response(:created)

      assert %{"id" => id} = data
    end

    @tag :admin_authenticated
    test "renders rule when data is valid without business concept", %{
      conn: conn,
      swagger_schema: schema
    } do
      rule_params =
        string_params_for(:rule)
        |> Map.delete("business_concept_id")

      assert %{"data" => data} =
               conn
               |> post(Routes.rule_path(conn, :create), rule: rule_params)
               |> validate_resp_schema(schema, "RuleResponse")
               |> json_response(:created)

      assert %{"id" => _id, "business_concept_id" => nil} = data
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      params = string_params_for(:rule, name: nil)

      assert %{"errors" => _errors} =
               conn
               |> post(Routes.rule_path(conn, :create), rule: params)
               |> json_response(:unprocessable_entity)
    end

    @tag :admin_authenticated
    test "renders errors when rule result type is numeric and goal is higher than minimum", %{
      conn: conn
    } do
      params = string_params_for(:rule, minimum: 5, goal: 10, result_type: "errors_number")

      assert %{"errors" => errors} =
               conn
               |> post(Routes.rule_path(conn, :create), rule: params)
               |> json_response(:unprocessable_entity)

      assert %{"minimum" => ["must.be.greater.than.or.equal.to.goal"]} = errors
    end

    @tag :admin_authenticated
    test "renders errors when rule result type is percentage and goal is lower than minimum", %{
      conn: conn
    } do
      params = string_params_for(:rule, result_type: "percentage", minimum: 50, goal: 10)

      assert %{"errors" => errors} =
               conn
               |> post(Routes.rule_path(conn, :create), rule: params)
               |> json_response(:unprocessable_entity)

      assert %{"goal" => ["must.be.greater.than.or.equal.to.minimum"]} = errors
    end
  end

  describe "update rule" do
    setup do
      [rule: insert(:rule)]
    end

    @tag :admin_authenticated
    test "renders rule when data is valid", %{
      conn: conn,
      rule: %Rule{id: id} = rule,
      swagger_schema: schema
    } do
      params = string_params_for(:rule)

      assert %{"data" => data} =
               conn
               |> put(Routes.rule_path(conn, :update, rule), rule: params)
               |> validate_resp_schema(schema, "RuleResponse")
               |> json_response(:ok)

      assert %{"id" => ^id} = data
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn, rule: rule, swagger_schema: schema} do
      params = %{"name" => nil}

      assert %{"errors" => errors} =
               conn
               |> put(Routes.rule_path(conn, :update, rule), rule: params)
               |> validate_resp_schema(schema, "RuleResponse")
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end
  end

  describe "delete rule" do
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
end
