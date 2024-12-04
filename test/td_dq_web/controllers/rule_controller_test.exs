defmodule TdDqWeb.RuleControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger_dq.json"

  alias TdCache.Audit
  alias TdCache.Redix
  alias TdDq.Rules.Rule

  @identifier_template %{
    id: System.unique_integer([:positive]),
    label: "identifier_test",
    name: "identifier_test",
    scope: "dq",
    content: [
      %{
        "name" => "Identifier Template",
        "fields" => [
          %{
            "cardinality" => "1",
            "label" => "identifier_field",
            "name" => "identifier_field",
            "subscribable" => false,
            "type" => "string",
            "values" => nil,
            "widget" => "identifier"
          }
        ]
      }
    ]
  }

  @df_template %{
    id: System.unique_integer([:positive]),
    label: "df_test",
    name: "df_test",
    scope: "dq",
    content: [
      %{
        "name" => "Content Template",
        "fields" => [
          %{
            "cardinality" => "?",
            "label" => "foo",
            "name" => "foo",
            "subscribable" => false,
            "type" => "string",
            "values" => nil,
            "widget" => "string"
          }
        ]
      }
    ]
  }

  setup tags do
    start_supervised!(TdDq.MockRelationCache)

    start_supervised!(TdDq.Cache.RuleLoader)

    on_exit(fn -> Redix.del!(Audit.stream()) end)

    %{id: domain_id} =
      domain =
      case tags do
        %{domain: domain} -> domain
        _ -> CacheHelpers.insert_domain()
      end

    [rule: insert(:rule, domain_id: domain_id), domain: domain]
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

    @tag authentication: [user_name: "not_an_admin", permissions: [:view_quality_rule]]
    test "lists all rules depending on permissions", %{
      conn: conn,
      rule: %{id: rule_id},
      swagger_schema: schema
    } do
      insert(:rule)

      assert %{"data" => data} =
               conn
               |> get(Routes.rule_path(conn, :index))
               |> validate_resp_schema(schema, "RulesResponse")
               |> json_response(:ok)

      assert [%{"id" => ^rule_id}] = data
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

    @tag authentication: [role: "admin"]
    test "gets rule by id with current concept version in browser lang", %{
      conn: conn,
      swagger_schema: schema
    } do
      concept_id = System.unique_integer([:positive])
      concept_name_es = "concept_name_es"

      CacheHelpers.insert_concept(%{
        id: concept_id,
        business_concept_version_id: concept_id,
        status: "published",
        name: "concept_name_en",
        i18n: %{
          "es" => %{
            "name" => concept_name_es,
            "content" => %{}
          }
        }
      })

      %{id: id} = insert(:rule, business_concept_id: concept_id)

      assert %{
               "data" => %{
                 "current_business_concept_version" => %{
                   "name" => ^concept_name_es
                 }
               }
             } =
               conn
               |> put_req_header("accept-language", "es")
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

    @tag authentication: [user_name: "not_an_admin", permissions: [:view_quality_rule]]
    test "gets rule when user has permissions", %{
      conn: conn,
      swagger_schema: schema,
      domain: %{id: domain_id}
    } do
      business_concept_id = System.unique_integer([:positive])

      %{id: id, name: name} =
        insert(:rule, business_concept_id: business_concept_id, domain_id: domain_id)

      %{"data" => %{"id" => ^id, "name" => ^name}} =
        conn
        |> get(Routes.rule_path(conn, :show, id))
        |> validate_resp_schema(schema, "RuleResponse")
        |> json_response(:ok)
    end
  end

  describe "get_rules_by_concept" do
    @tag authentication: [role: "admin"]
    test "lists all rules of a concept", %{conn: conn, swagger_schema: schema, domain: domain} do
      business_concept_id = System.unique_integer([:positive])
      CacheHelpers.insert_concept(%{id: business_concept_id, domain_id: domain.id})

      %{id: id1, business_concept_id: business_concept_id} =
        insert(:rule, business_concept_id: business_concept_id)

      %{id: id2} = insert(:rule, business_concept_id: business_concept_id)

      assert %{"data" => data} =
               conn
               |> get(Routes.rule_path(conn, :get_rules_by_concept, business_concept_id))
               |> validate_resp_schema(schema, "RulesResponse")
               |> json_response(:ok)

      assert [
               %{"id" => ^id1, "business_concept_id" => ^business_concept_id},
               %{"id" => ^id2, "business_concept_id" => ^business_concept_id}
             ] = Enum.sort_by(data, & &1["id"])
    end

    @tag authentication: [role: "admin"]
    test "lists domains which the user can manage a concept", %{
      conn: conn,
      swagger_schema: schema,
      domain: %{id: domain_id}
    } do
      business_concept_id = System.unique_integer([:positive])
      %{id: another_domain_id} = CacheHelpers.insert_domain()

      CacheHelpers.insert_concept(%{
        id: business_concept_id,
        domain_id: domain_id,
        shared_to_ids: [another_domain_id]
      })

      assert %{"_actions" => actions} =
               conn
               |> get(Routes.rule_path(conn, :get_rules_by_concept, business_concept_id))
               |> validate_resp_schema(schema, "RulesResponse")
               |> json_response(:ok)

      assert %{"domain_ids" => [%{"id" => ^domain_id}, %{"id" => ^another_domain_id}]} = actions
    end

    @tag authentication: [role: "admin"]
    test "lists all rules of a concept with entiched domains", %{
      conn: conn,
      domain: %{id: domain_id, external_id: external_id, name: name},
      swagger_schema: schema
    } do
      business_concept_id = System.unique_integer([:positive])
      CacheHelpers.insert_concept(%{id: business_concept_id, domain_id: domain_id})
      %{id: id1} = insert(:rule, domain_id: domain_id, business_concept_id: business_concept_id)

      %{id: id2} = insert(:rule, domain_id: domain_id, business_concept_id: business_concept_id)

      assert %{
               "data" => [
                 %{
                   "domain" => %{
                     "id" => ^domain_id,
                     "name" => ^name,
                     "external_id" => ^external_id
                   },
                   "id" => ^id1
                 },
                 %{
                   "domain" => %{
                     "id" => ^domain_id,
                     "name" => ^name,
                     "external_id" => ^external_id
                   },
                   "id" => ^id2
                 }
               ]
             } =
               conn
               |> get(Routes.rule_path(conn, :get_rules_by_concept, business_concept_id))
               |> validate_resp_schema(schema, "RulesResponse")
               |> json_response(:ok)
    end

    @tag authentication: [
           user_name: "not_an_admin",
           permissions: [:view_quality_rule, :manage_confidential_business_concepts]
         ]
    test "lists all rules of a confidential concept", %{
      conn: conn,
      swagger_schema: schema,
      domain: domain
    } do
      business_concept_id = System.unique_integer([:positive])

      CacheHelpers.insert_concept(%{
        id: business_concept_id,
        domain_id: domain.id,
        confidential: true
      })

      %{id: id1, business_concept_id: business_concept_id} =
        insert(:rule, business_concept_id: business_concept_id, domain_id: domain.id)

      %{id: id2} = insert(:rule, business_concept_id: business_concept_id, domain_id: domain.id)

      assert %{"data" => data} =
               conn
               |> get(Routes.rule_path(conn, :get_rules_by_concept, business_concept_id))
               |> validate_resp_schema(schema, "RulesResponse")
               |> json_response(:ok)

      assert [
               %{"id" => ^id1, "business_concept_id" => ^business_concept_id},
               %{"id" => ^id2, "business_concept_id" => ^business_concept_id}
             ] = Enum.sort_by(data, & &1["id"])
    end

    @tag authentication: [role: "admin"]
    test "lists all rules of a concept with expandable link", %{
      conn: conn,
      domain: domain
    } do
      %{id: bc_id} = CacheHelpers.insert_concept(%{domain_id: domain.id})
      %{id: bc_expandable_id, name: bc_name} = CacheHelpers.insert_concept()
      %{id: bc_non_expandable_id} = CacheHelpers.insert_concept()

      %{id: id1, business_concept_id: bc_id} = insert(:rule, business_concept_id: bc_id)
      %{id: id2} = insert(:rule, business_concept_id: bc_expandable_id)
      insert(:rule, business_concept_id: bc_non_expandable_id)

      type_expandable = "expandable"
      CacheHelpers.insert_tag(type_expandable, "business_concept", true)

      CacheHelpers.insert_link(
        bc_id,
        "business_concept",
        "business_concept",
        bc_expandable_id,
        [type_expandable]
      )

      CacheHelpers.insert_link(
        bc_id,
        "business_concept",
        "business_concept",
        bc_non_expandable_id
      )

      assert %{"data" => data} =
               conn
               |> get(Routes.rule_path(conn, :get_rules_by_concept, bc_id))
               |> json_response(:ok)

      assert [
               %{"id" => ^id1, "business_concept_id" => ^bc_id},
               %{
                 "id" => ^id2,
                 "business_concept_id" => ^bc_expandable_id,
                 "business_concept_name" => ^bc_name
               }
             ] = Enum.sort_by(data, & &1["id"])
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
    test "renders rule when data is valid", %{conn: conn, swagger_schema: schema, domain: domain} do
      params = string_params_for(:rule, domain_id: domain.id) |> Map.delete("business_concept_id")

      assert %{"data" => data} =
               conn
               |> post(Routes.rule_path(conn, :create), rule: params)
               |> validate_resp_schema(schema, "RuleResponse")
               |> json_response(:created)

      assert %{"id" => _id} = data
    end

    @tag authentication: [user_name: "non_admin"]
    test "user without permissions cannot create rule", %{conn: conn, domain: domain} do
      params =
        string_params_for(:rule, domain_id: domain.id)
        |> Map.delete("business_concept_id")

      assert conn
             |> post(Routes.rule_path(conn, :create), rule: params)
             |> json_response(:forbidden)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:manage_quality_rule]
         ]
    test "user with permissions can create rule", %{conn: conn, domain: domain} do
      params = string_params_for(:rule, domain_id: domain.id) |> Map.delete("business_concept_id")

      assert conn
             |> post(Routes.rule_path(conn, :create), rule: params)
             |> json_response(:created)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:manage_quality_rule]
         ]
    test "user with permissions can create rule at same business concept domain", %{
      conn: conn,
      domain: domain
    } do
      business_concept_id = System.unique_integer([:positive])
      CacheHelpers.insert_concept(%{id: business_concept_id, domain_id: domain.id})

      params =
        string_params_for(:rule, domain_id: domain.id, business_concept_id: business_concept_id)

      assert conn
             |> post(Routes.rule_path(conn, :create), rule: params)
             |> json_response(:created)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:manage_quality_rule]
         ]
    test "user with permissions can not create rule in a different domain to business concept", %{
      conn: conn,
      domain: domain
    } do
      business_concept_id = System.unique_integer([:positive])

      CacheHelpers.insert_concept(%{
        id: business_concept_id,
        domain_id: CacheHelpers.insert_domain().id
      })

      params =
        string_params_for(:rule, domain_id: domain.id, business_concept_id: business_concept_id)

      assert conn
             |> post(Routes.rule_path(conn, :create), rule: params)
             |> json_response(:forbidden)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:manage_quality_rule]
         ]
    test "user with permissions can create rule in a shared domain of business concept", %{
      conn: conn,
      domain: domain
    } do
      business_concept_id = System.unique_integer([:positive])

      CacheHelpers.insert_concept(%{
        id: business_concept_id,
        domain_id: CacheHelpers.insert_domain().id,
        shared_to_ids: [domain.id]
      })

      params =
        string_params_for(:rule, domain_id: domain.id, business_concept_id: business_concept_id)

      assert conn
             |> post(Routes.rule_path(conn, :create), rule: params)
             |> json_response(:created)
    end

    @tag authentication: [role: "admin"]
    test "renders rule when data is valid without business concept", %{
      conn: conn,
      domain: domain,
      swagger_schema: schema
    } do
      rule_params =
        string_params_for(:rule, domain_id: domain.id)
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
      params = string_params_for(:rule, name: nil) |> Map.delete("business_concept_id")

      assert %{"errors" => _errors} =
               conn
               |> post(Routes.rule_path(conn, :create), rule: params)
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "renders dynamic content and legacy content", %{conn: conn, domain: domain} do
      %{name: template_name} = CacheHelpers.insert_template(@df_template)

      params =
        string_params_for(:rule,
          domain_id: domain.id,
          df_name: template_name,
          df_content: %{"foo" => %{"value" => "bar", "origin" => "user"}}
        )
        |> Map.delete("business_concept_id")

      assert %{
               "data" => data
             } =
               conn
               |> post(Routes.rule_path(conn, :create), rule: params)
               |> json_response(:created)

      assert %{
               "df_content" => %{"foo" => "bar"},
               "dynamic_content" => %{"foo" => %{"value" => "bar", "origin" => "user"}}
             } = data
    end

    @tag authentication: [role: "admin"]
    test "generates identifier in template", %{conn: conn, domain: domain} do
      %{name: template_name} = CacheHelpers.insert_template(@identifier_template)

      params =
        string_params_for(:rule,
          domain_id: domain.id,
          df_name: template_name,
          df_content: %{"identifier_field" => %{"value" => "", "origin" => "user"}}
        )
        |> Map.delete("business_concept_id")

      assert %{
               "data" => %{"id" => _id, "df_content" => %{"identifier_field" => identifier_value}}
             } =
               conn
               |> post(Routes.rule_path(conn, :create), rule: params)
               |> json_response(:created)

      refute is_nil(identifier_value) or identifier_value == ""
    end
  end

  describe "update rule" do
    setup tags do
      domain_id = get_in(tags, [:domain, :id])
      [rule: insert(:rule, domain_id: domain_id)]
    end

    @tag authentication: [role: "admin"]
    test "renders rule when data is valid", %{
      conn: conn,
      rule: %Rule{id: id, domain_id: domain_id} = rule,
      swagger_schema: schema
    } do
      params =
        string_params_for(:rule, domain_id: domain_id)
        |> Map.delete("business_concept_id")

      assert %{"data" => data} =
               conn
               |> put(Routes.rule_path(conn, :update, rule), rule: params)
               |> validate_resp_schema(schema, "RuleResponse")
               |> json_response(:ok)

      assert %{"id" => ^id} = data
    end

    @tag authentication: [user_name: "non_admin"]
    test "user without permissions cannot update rule", %{
      conn: conn,
      rule: %Rule{domain_id: domain_id} = rule
    } do
      params =
        string_params_for(:rule, domain_id: domain_id)
        |> Map.delete("business_concept_id")
        |> Map.delete("domain_id")

      assert conn
             |> put(Routes.rule_path(conn, :update, rule), rule: params)
             |> json_response(:forbidden)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:manage_quality_rule]
         ]
    test "user with permissions can only update rule of its domain", %{
      conn: conn,
      rule: %Rule{} = rule,
      domain: domain
    } do
      CacheHelpers.insert_concept(%{id: rule.business_concept_id, domain_id: domain.id})

      params =
        string_params_for(:rule,
          domain_id: domain.id,
          business_concept_id: rule.business_concept_id
        )

      assert conn
             |> put(Routes.rule_path(conn, :update, rule), rule: params)
             |> json_response(:ok)

      forbidden_rule = insert(:rule)
      CacheHelpers.insert_concept(%{id: forbidden_rule.business_concept_id, domain_id: domain.id})

      params =
        string_params_for(:rule,
          business_concept_id: forbidden_rule.business_concept_id,
          domain_id: domain.id
        )

      assert conn
             |> put(Routes.rule_path(conn, :update, forbidden_rule), rule: params)
             |> json_response(:forbidden)
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

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:manage_quality_rule]
         ]
    test "user with permissions can update a business concept rule from a shared domain", %{
      conn: conn,
      rule: %Rule{} = rule,
      domain: domain
    } do
      %{id: another_domain_id} = CacheHelpers.insert_domain()

      CacheHelpers.insert_concept(%{
        id: rule.business_concept_id,
        domain_id: another_domain_id,
        shared_to_ids: [domain.id]
      })

      params =
        string_params_for(:rule,
          domain_id: domain.id,
          business_concept_id: rule.business_concept_id
        )

      assert conn
             |> put(Routes.rule_path(conn, :update, rule), rule: params)
             |> json_response(:ok)
    end

    @tag authentication: [
           user_name: "non_admin",
           permissions: [:manage_quality_rule]
         ]
    test "user with permissions can not update a business concept rule from a distinct domain", %{
      conn: conn,
      rule: %Rule{} = rule,
      domain: domain
    } do
      %{id: another_domain_id} = CacheHelpers.insert_domain()
      CacheHelpers.insert_concept(%{id: rule.business_concept_id, domain_id: another_domain_id})

      params =
        string_params_for(:rule,
          domain_id: domain.id,
          business_concept_id: rule.business_concept_id
        )

      assert conn
             |> put(Routes.rule_path(conn, :update, rule), rule: params)
             |> json_response(:forbidden)
    end
  end

  describe "delete rule" do
    @tag authentication: [role: "admin"]
    test "deletes chosen rule", %{conn: conn, rule: rule} do
      assert conn
             |> delete(Routes.rule_path(conn, :delete, rule))
             |> response(:no_content)
    end

    @tag authentication: [user_name: "non_admin"]
    test "user without permissions cannot delete rule", %{conn: conn, rule: rule} do
      assert conn
             |> delete(Routes.rule_path(conn, :delete, rule))
             |> response(:forbidden)
    end
  end
end
