defmodule TdDdWeb.Schema.GrantApprovalRulesTest do
  use TdDdWeb.ConnCase

  @grant_approval_rules """
  query GrantApprovalRules {
    grantApprovalRules {
      id
      domains {
        name
      }
    }
  }
  """

  @grant_approval_rule """
  query GrantApprovalRule($id: ID!) {
    grantApprovalRule(id: $id) {
      id
      action
      role
      domainIds
      userId
      conditions {
        field
        operator
        values
      }
      comment
    }
  }
  """

  @create_grant_approval_rule """
  mutation CreateGrantApprovalRule($approvalRule: CreateGrantApprovalRuleInput!) {
    createGrantApprovalRule(approvalRule: $approvalRule) {
      id
      action
      role
      domainIds
      userId
    }
  }
  """

  @update_grant_approval_rule """
  mutation UpdateGrantApprovalRule($approvalRule: UpdateGrantApprovalRuleInput!) {
    updateGrantApprovalRule(approvalRule: $approvalRule) {
      id
      action
      role
      domainIds
      userId
      comment
      conditions {
        field
        operator
        values
      }
    }
  }
  """

  @delete_grant_approval_rule """
  mutation DeleteGrantApprovalRule($id: ID!) {
    deleteGrantApprovalRule(id: $id) {
      id
    }
  }
  """

  describe "GrantApprovalRules query" do
    @tag authentication: [role: "user"]
    test "return forbidden if user has no permissions", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @grant_approval_rules})
               |> json_response(:ok)

      assert data == %{"grantApprovalRules" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: [:approve_grant_request]]
    test "return list of approvals when queried by user", %{
      conn: conn,
      claims: %{user_id: user_id},
      domain: %{id: domain_id, name: domain_name}
    } do
      insert(:approval_rule)

      %{id: id_1} = insert(:approval_rule, user_id: user_id, domain_ids: [domain_id])

      %{id: id_2} = insert(:approval_rule, user_id: user_id, domain_ids: [domain_id])

      id_1_str = to_string(id_1)
      id_2_str = to_string(id_2)

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @grant_approval_rules})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"grantApprovalRules" => grant_approvals} = data

      assert [
               %{"id" => ^id_1_str, "domains" => [%{"name" => ^domain_name}]},
               %{"id" => ^id_2_str, "domains" => [%{"name" => ^domain_name}]}
             ] = grant_approvals
    end
  end

  describe "GrantApprovalRule query" do
    @tag authentication: [role: "user"]
    test "return forbidden if user has no permissions", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @grant_approval_rule,
                 "variables" => %{"id" => 123}
               })
               |> json_response(:ok)

      assert data == %{"grantApprovalRule" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: [:approve_grant_request]]
    test "return data when queried by user with permissions", %{
      conn: conn,
      claims: %{user_id: user_id},
      domain: %{id: domain_id}
    } do
      insert(:approval_rule, user_id: user_id, domain_ids: [domain_id])

      %{id: approval_id} =
        insert(:approval_rule,
          user_id: user_id,
          domain_ids: [domain_id],
          action: "reject",
          comment: "bla"
        )

      assert %{"data" => %{"grantApprovalRule" => approval_rule}} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @grant_approval_rule,
                 "variables" => %{"id" => approval_id}
               })
               |> json_response(:ok)

      assert response["errors"] == nil

      string_domain_id = to_string(domain_id)
      string_approval_id = to_string(approval_id)
      string_user_id = to_string(user_id)

      assert %{
               "action" => "reject",
               "comment" => "bla",
               "conditions" => [
                 %{"field" => "foo", "operator" => "is", "values" => ["bar"]}
               ],
               "domainIds" => [^string_domain_id],
               "id" => ^string_approval_id,
               "userId" => ^string_user_id,
               "role" => "role1"
             } = approval_rule
    end

    @tag authentication: [role: "user", permissions: [:approve_grant_request]]
    test "return not found error on invalid approve_rule id", %{conn: conn} do
      invalid_approval_rule_id = 1

      assert %{"data" => %{"grantApprovalRule" => nil}, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @grant_approval_rule,
                 "variables" => %{"id" => invalid_approval_rule_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "not_found"}] = errors
    end
  end

  describe "Create GrantApprovalRule mutation" do
    @tag authentication: [role: "user", permissions: [:approve_grant_request]]
    test "create approval rule by user with permissions", %{
      conn: conn,
      domain: %{id: domain_id},
      claims: %{user_id: user_id}
    } do
      role_name = "approval_role"

      CacheHelpers.insert_acl(domain_id, role_name, [user_id])

      approval_rule_params =
        :approval_rule
        |> string_params_for(domain_ids: [domain_id], role: role_name)
        |> Map.take([
          "name",
          "action",
          "role",
          "domain_ids",
          "conditions",
          "comment"
        ])

      variables = %{"approvalRule" => approval_rule_params}

      assert %{"data" => %{"createGrantApprovalRule" => approval_rule}} =
               conn
               |> post("/api/v2", %{
                 "query" => @create_grant_approval_rule,
                 "variables" => variables
               })
               |> json_response(:ok)

      string_domain_id = to_string(domain_id)
      string_user_id = to_string(user_id)

      assert %{
               "action" => "approve",
               "domainIds" => [^string_domain_id],
               "id" => _,
               "userId" => ^string_user_id,
               "role" => ^role_name
             } = approval_rule
    end

    @tag authentication: [role: "user"]
    test "return forbidden if user has no permissions", %{
      conn: conn
    } do
      approval_rule_params =
        :approval_rule
        |> string_params_for()
        |> Map.take([
          "name",
          "action",
          "role",
          "domain_ids",
          "conditions",
          "comment"
        ])

      variables = %{"approvalRule" => approval_rule_params}

      assert %{"data" => %{"createGrantApprovalRule" => nil}, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @create_grant_approval_rule,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: [:approve_grant_request]]
    test "return error when user doesn't have a role with approve_grant_request", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      approval_rule_params =
        :approval_rule
        |> string_params_for(domain_ids: [domain_id])
        |> Map.take([
          "name",
          "action",
          "role",
          "domain_ids",
          "conditions",
          "comment"
        ])

      variables = %{"approvalRule" => approval_rule_params}

      assert %{"data" => %{"createGrantApprovalRule" => nil}, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @create_grant_approval_rule,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert [%{"message" => "user_id invalid role"}] = errors
    end
  end

  describe "Update GrantApprovalRule mutation" do
    @tag authentication: [role: "user", permissions: [:approve_grant_request]]
    test "update approval rule by user with permissions", %{
      conn: conn,
      domain: %{id: domain_id},
      claims: %{user_id: user_id}
    } do
      role_name = "approval_role"
      CacheHelpers.insert_acl(domain_id, role_name, [user_id])

      %{id: approval_id} =
        insert(:approval_rule, user_id: user_id, domain_ids: [domain_id], role: role_name)

      approval_rule_params = %{
        "id" => approval_id,
        "comment" => "new_comment",
        "action" => "reject",
        "conditions" => [
          %{"field" => "new", "operator" => "is not", "values" => ["condition"]}
        ]
      }

      variables = %{"approvalRule" => approval_rule_params}

      assert %{"data" => %{"updateGrantApprovalRule" => approval_rule}} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_grant_approval_rule,
                 "variables" => variables
               })
               |> json_response(:ok)

      string_domain_id = to_string(domain_id)
      string_user_id = to_string(user_id)
      string_approval_id = to_string(approval_id)

      assert %{
               "comment" => "new_comment",
               "action" => "reject",
               "conditions" => [
                 %{"field" => "new", "operator" => "is not", "values" => ["condition"]}
               ],
               "domainIds" => [^string_domain_id],
               "id" => ^string_approval_id,
               "userId" => ^string_user_id,
               "role" => ^role_name
             } = approval_rule
    end

    @tag authentication: [role: "user"]
    test "return forbidden if user has no permissions", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: approval_id} = insert(:approval_rule, user_id: user_id)

      approval_rule_params = %{
        "id" => approval_id,
        "comment" => "new_comment"
      }

      variables = %{"approvalRule" => approval_rule_params}

      assert %{"data" => %{"updateGrantApprovalRule" => nil}, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_grant_approval_rule,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: [:approve_grant_request]]
    test "return error when user doesn't have a role with approve_grant_request", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: approval_id} = insert(:approval_rule, user_id: user_id)

      approval_rule_params = %{
        "id" => approval_id,
        "comment" => "new_comment"
      }

      variables = %{"approvalRule" => approval_rule_params}

      assert %{"data" => %{"updateGrantApprovalRule" => nil}, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_grant_approval_rule,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert [%{"message" => "user_id invalid role"}] = errors
    end

    @tag authentication: [role: "user", permissions: [:approve_grant_request]]
    test "return error when trying to update approval_rule not owned", %{
      conn: conn,
      domain: %{id: domain_id},
      claims: %{user_id: user_id}
    } do
      role_name = "approval_role"
      CacheHelpers.insert_acl(domain_id, role_name, [user_id])
      %{id: approval_id} = insert(:approval_rule, domain_ids: [domain_id], role: role_name)

      approval_rule_params = %{
        "id" => approval_id,
        "comment" => "new_comment"
      }

      variables = %{"approvalRule" => approval_rule_params}

      assert %{"data" => %{"updateGrantApprovalRule" => nil}, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @update_grant_approval_rule,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end
  end

  describe "Delete GrantApprovalRule mutation" do
    @tag authentication: [role: "user", permissions: [:approve_grant_request]]
    test "delete approval rule by user with permissions", %{
      conn: conn,
      domain: %{id: domain_id},
      claims: %{user_id: user_id}
    } do
      role_name = "approval_role"
      CacheHelpers.insert_acl(domain_id, role_name, [user_id])

      %{id: approval_id} =
        insert(:approval_rule, user_id: user_id, domain_ids: [domain_id], role: role_name)

      variables = %{"id" => approval_id}

      assert %{"data" => %{"deleteGrantApprovalRule" => approval_rule}} =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_grant_approval_rule,
                 "variables" => variables
               })
               |> json_response(:ok)

      string_approval_id = to_string(approval_id)

      assert %{"id" => ^string_approval_id} = approval_rule
    end

    @tag authentication: [role: "user"]
    test "return forbidden if user has no permissions", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: approval_id} = insert(:approval_rule, user_id: user_id)

      variables = %{"id" => approval_id}

      assert %{"data" => %{"deleteGrantApprovalRule" => nil}, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_grant_approval_rule,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: [:approve_grant_request]]
    test "return error when trying to delete approval_rule not owned", %{
      conn: conn,
      domain: %{id: domain_id},
      claims: %{user_id: user_id}
    } do
      role_name = "approval_role"
      CacheHelpers.insert_acl(domain_id, role_name, [user_id])
      %{id: approval_id} = insert(:approval_rule, domain_ids: [domain_id], role: role_name)
      variables = %{"id" => approval_id}

      assert %{"data" => %{"deleteGrantApprovalRule" => nil}, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @delete_grant_approval_rule,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end
  end
end
