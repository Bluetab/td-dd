defmodule TdDqWeb.RuleControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger_dq.json"

  alias TdCache.{Audit, Redix}
  alias TdDq.Rules.Rule

  setup_all do
    domain = CacheHelpers.insert_domain()
    [domain: domain]
  end

  setup tags do
    start_supervised!(TdDq.MockRelationCache)
    start_supervised!(TdDd.Search.MockIndexWorker)
    start_supervised!(TdDq.Cache.RuleLoader)
    on_exit(fn -> Redix.del!(Audit.stream()) end)
    domain_id = get_in(tags, [:domain, :id])
    [rule: insert(:rule, domain_id: domain_id)]
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all rules", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => [_rule]} =
               conn
               |> get(Routes.rule_path(conn, :index))
               |> validate_resp_schema(schema, "RulesResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "lists all rules with preloaded domains", %{
      conn: conn,
      domain: %{id: domain_id, external_id: external_id, name: name},
      rule: %{id: rule_id},
      swagger_schema: schema
    } do
      assert %{
               "data" => [
                 %{
                   "id" => ^rule_id,
                   "domain_id" => ^domain_id,
                   "domain" => %{
                     "id" => ^domain_id,
                     "name" => ^name,
                     "external_id" => ^external_id
                   }
                 }
               ]
             } =
               conn
               |> get(Routes.rule_path(conn, :index))
               |> validate_resp_schema(schema, "RulesResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "service"]
    test "service account can view all rules", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => [_rule]} =
               conn
               |> get(Routes.rule_path(conn, :index))
               |> validate_resp_schema(schema, "RulesResponse")
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "lists all rules depending on permissions", %{
      conn: conn,
      claims: %{user_id: user_id},
      swagger_schema: schema
    } do
      business_concept_id = Integer.to_string(System.unique_integer([:positive]))
      %{id: id} = insert(:rule, business_concept_id: business_concept_id)
      insert(:rule, business_concept_id: "1234")

      create_acl_entry(user_id, "business_concept", business_concept_id, [:view_quality_rule])

      assert %{"data" => data} =
               conn
               |> get(Routes.rule_path(conn, :index))
               |> validate_resp_schema(schema, "RulesResponse")
               |> json_response(:ok)

      assert [%{"id" => ^id}] = data
    end
  end

  describe "get rule" do
    @tag authentication: [role: "admin"]
    test "gets rule by id", %{conn: conn, swagger_schema: schema} do
      %{id: id, name: name} = insert(:rule)

      assert %{"data" => %{"id" => ^id, "name" => ^name}} =
               conn
               |> get(Routes.rule_path(conn, :show, id))
               |> validate_resp_schema(schema, "RuleResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "gets rule by id with enriched domain", %{
      conn: conn,
      domain: %{id: domain_id, external_id: external_id, name: domain_name},
      swagger_schema: schema
    } do
      %{id: id, name: name} = insert(:rule, domain_id: domain_id)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "name" => ^name,
                 "domain_id" => ^domain_id,
                 "domain" => %{
                   "id" => ^domain_id,
                   "name" => ^domain_name,
                   "external_id" => ^external_id
                 }
               }
             } =
               conn
               |> get(Routes.rule_path(conn, :show, id))
               |> validate_resp_schema(schema, "RuleResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "unauthorized when user has no permissions", %{
      conn: conn
    } do
      %{id: id} = insert(:rule)

      assert %{"errors" => %{"detail" => "Forbidden"}} =
               conn
               |> get(Routes.rule_path(conn, :show, id))
               |> json_response(:forbidden)
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "gets rule when user has permissions", %{
      conn: conn,
      claims: %{user_id: user_id},
      swagger_schema: schema
    } do
      business_concept_id = Integer.to_string(System.unique_integer([:positive]))
      %{id: id, name: name} = insert(:rule, business_concept_id: business_concept_id)
      create_acl_entry(user_id, "business_concept", business_concept_id, [:view_quality_rule])

      %{"data" => %{"id" => ^id, "name" => ^name}} =
        conn
        |> get(Routes.rule_path(conn, :show, id))
        |> validate_resp_schema(schema, "RuleResponse")
        |> json_response(:ok)
    end
  end

  describe "get_rules_by_concept" do
    @tag authentication: [role: "admin"]
    test "lists all rules of a concept", %{conn: conn, swagger_schema: schema} do
      business_concept_id = Integer.to_string(System.unique_integer([:positive]))

      %{id: id1, business_concept_id: business_concept_id} =
        insert(:rule, business_concept_id: business_concept_id)

      %{id: id2} = insert(:rule, business_concept_id: business_concept_id)

      assert %{
               "data" => [
                 %{"id" => ^id1, "business_concept_id" => ^business_concept_id},
                 %{"id" => ^id2, "business_concept_id" => ^business_concept_id}
               ]
             } =
               conn
               |> get(Routes.rule_path(conn, :get_rules_by_concept, business_concept_id))
               |> validate_resp_schema(schema, "RulesResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "lists all rules of a concept with entiched domains", %{
      conn: conn,
      domain: %{id: domain_id, external_id: external_id, name: name},
      swagger_schema: schema
    } do
      business_concept_id = Integer.to_string(System.unique_integer([:positive]))
      %{id: id1} = insert(:rule, domain_id: domain_id, business_concept_id: business_concept_id)

      %{id: id2} = insert(:rule, domain_id: domain_id, business_concept_id: business_concept_id)

      assert %{
               "data" => [
                 %{
                   "id" => ^id1,
                   "domain" => %{
                     "id" => ^domain_id,
                     "name" => ^name,
                     "external_id" => ^external_id
                   }
                 },
                 %{
                   "id" => ^id2,
                   "domain" => %{
                     "id" => ^domain_id,
                     "name" => ^name,
                     "external_id" => ^external_id
                   }
                 }
               ]
             } =
               conn
               |> get(Routes.rule_path(conn, :get_rules_by_concept, business_concept_id))
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
    @tag authentication: [role: "admin"]
    test "renders rule when data is valid", %{conn: conn, swagger_schema: schema} do
      params = string_params_for(:rule)

      assert %{"data" => data} =
               conn
               |> post(Routes.rule_path(conn, :create), rule: params)
               |> validate_resp_schema(schema, "RuleResponse")
               |> json_response(:created)

      assert %{"id" => _id} = data
    end

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      params = string_params_for(:rule, name: nil)

      assert %{"errors" => _errors} =
               conn
               |> post(Routes.rule_path(conn, :create), rule: params)
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "admin"]
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

    @tag authentication: [role: "admin"]
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
    @tag authentication: [role: "admin"]
    test "deletes chosen rule", %{conn: conn, rule: rule} do
      assert conn
             |> delete(Routes.rule_path(conn, :delete, rule))
             |> response(:no_content)
    end
  end
end
