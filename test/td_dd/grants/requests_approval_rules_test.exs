defmodule TdDd.Grants.RequestsApprovalRulesTest do
  use TdDd.DataCase

  alias TdDd.Grants.ApprovalRules
  alias TdDd.Grants.Requests

  @moduletag sandbox: :shared

  @template_name "grant_request_test_template"
  @valid_metadata %{"list" => "one", "string" => "bar"}

  @approver_role "approver_role"

  setup _tags do
    start_supervised!(TdDd.Search.StructureEnricher)

    template = CacheHelpers.insert_template(name: @template_name)

    %{id: domain_id} = CacheHelpers.insert_domain()
    %{id: approver_user_id} = CacheHelpers.insert_user()

    CacheHelpers.put_grant_request_approvers([
      %{user_id: approver_user_id, resource_id: domain_id, role: @approver_role}
    ])

    domain_ids = [domain_id]

    data_structure = insert(:data_structure, domain_ids: domain_ids)
    data_structure_version = insert(:data_structure_version, data_structure: data_structure)

    [
      template: template,
      domain_ids: domain_ids,
      approver_user_id: approver_user_id,
      data_structure: data_structure,
      data_structure_version: data_structure_version
    ]
  end

  describe "create_grant_request_group/2 rules approval" do
    test "approve rule with request metadata", %{
      approver_user_id: approver_user_id,
      domain_ids: domain_ids,
      data_structure: data_structure
    } do
      %{id: approval_rule_id} =
        insert(:approval_rule,
          role: @approver_role,
          user_id: approver_user_id,
          domain_ids: domain_ids,
          conditions: [%{field: "request.list", operator: "subset", values: ["one"]}]
        )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{
               current_status: "approved",
               approvals: [
                 %{
                   user_id: ^approver_user_id,
                   approval_rule_id: ^approval_rule_id
                 }
               ]
             } = Requests.get_grant_request!(request_id, claims)
    end

    test "approve rule with request metadata with more than one condition", %{
      approver_user_id: approver_user_id,
      domain_ids: domain_ids
    } do
      data_structure = insert(:data_structure, domain_ids: domain_ids)

      insert(:data_structure_version,
        data_structure: data_structure,
        metadata: %{"field" => "foo", "other" => "baz"}
      )

      insert(:approval_rule,
        role: @approver_role,
        user_id: approver_user_id,
        domain_ids: domain_ids,
        conditions: [
          %{field: "request.string", operator: "eq", value: "bar"},
          %{field: "metadata.field", operator: "eq", value: "foo"},
          %{field: "metadata.other", operator: "neq", value: "not_baz"}
        ]
      )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{
               current_status: "approved",
               approvals: [
                 %{user_id: ^approver_user_id}
               ]
             } = Requests.get_grant_request!(request_id, claims)
    end

    test "approve rule with structure metadata in a subdomain", %{
      approver_user_id: approver_user_id,
      domain_ids: [domain_id] = domain_ids
    } do
      %{id: subdomain_id} = CacheHelpers.insert_domain(%{parent_id: domain_id})

      %{data_structure: data_structure} =
        insert(:data_structure_version,
          data_structure:
            build(:data_structure,
              domain_ids: [subdomain_id]
            ),
          metadata: %{"field" => "foo", "other" => "baz"}
        )

      insert(:approval_rule,
        role: @approver_role,
        user_id: approver_user_id,
        domain_ids: domain_ids,
        conditions: [
          %{field: "metadata.field", operator: "eq", value: "foo"}
        ]
      )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{
               current_status: "approved",
               approvals: [
                 %{user_id: ^approver_user_id}
               ]
             } = Requests.get_grant_request!(request_id, claims)
    end

    test "approve rule with structure mutable metadata in a subdomain", %{
      approver_user_id: approver_user_id,
      domain_ids: [domain_id] = domain_ids
    } do
      %{id: subdomain_id} = CacheHelpers.insert_domain(%{parent_id: domain_id})

      %{data_structure: data_structure} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, domain_ids: [subdomain_id])
        )

      insert(:structure_metadata,
        data_structure: data_structure,
        fields: %{"foo" => "bar"}
      )

      insert(:approval_rule,
        role: @approver_role,
        user_id: approver_user_id,
        domain_ids: domain_ids,
        conditions: [
          %{field: "metadata.foo", operator: "eq", value: "bar"}
        ]
      )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{
               current_status: "approved",
               approvals: [
                 %{user_id: ^approver_user_id}
               ]
             } = Requests.get_grant_request!(request_id, claims)
    end

    test "approve rule with structure note in a subdomain", %{
      approver_user_id: approver_user_id,
      domain_ids: [domain_id] = domain_ids
    } do
      %{id: subdomain_id} = CacheHelpers.insert_domain(%{parent_id: domain_id})

      %{data_structure: data_structure} =
        insert(:data_structure_version,
          data_structure:
            build(:data_structure,
              domain_ids: [subdomain_id]
            ),
          metadata: %{"field" => "foo", "other" => "baz"}
        )

      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"foo" => "bar"},
        status: :published
      )

      insert(:approval_rule,
        role: @approver_role,
        user_id: approver_user_id,
        domain_ids: domain_ids,
        conditions: [%{field: "note.foo", operator: "eq", value: "bar"}]
      )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{
               current_status: "approved",
               approvals: [
                 %{user_id: ^approver_user_id}
               ]
             } = Requests.get_grant_request!(request_id, claims)
    end

    test "approve rule for structure with multiple domains", %{
      approver_user_id: approver_user_id,
      domain_ids: [domain_id_1]
    } do
      %{id: domain_id_2} = CacheHelpers.insert_domain()

      domain_ids = [domain_id_1, domain_id_2]

      %{data_structure: data_structure} =
        insert(:data_structure_version,
          data_structure:
            build(:data_structure,
              domain_ids: domain_ids
            ),
          metadata: %{"field" => "foo", "other" => "baz"}
        )

      insert(:approval_rule,
        role: @approver_role,
        user_id: approver_user_id,
        domain_ids: domain_ids,
        conditions: [
          %{field: "metadata.field", operator: "eq", value: "foo"}
        ]
      )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{
               current_status: "approved",
               approvals: [
                 %{user_id: ^approver_user_id}
               ]
             } = Requests.get_grant_request!(request_id, claims)
    end

    test "do not match rule if one condition is not met", %{
      approver_user_id: approver_user_id,
      domain_ids: domain_ids,
      data_structure: data_structure
    } do
      insert(:approval_rule,
        role: @approver_role,
        user_id: approver_user_id,
        domain_ids: domain_ids,
        conditions: [
          %{field: "request.string", operator: "eq", value: "foo"},
          %{field: "request.string", operator: "eq", value: "bar"}
        ]
      )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{
               current_status: "pending",
               approvals: []
             } = Requests.get_grant_request!(request_id, claims)
    end

    test "not equal condition requires the field to exist", %{
      approver_user_id: approver_user_id,
      domain_ids: domain_ids,
      data_structure: data_structure
    } do
      insert(:approval_rule,
        role: @approver_role,
        user_id: approver_user_id,
        domain_ids: domain_ids,
        conditions: [%{field: "request.non_existing_field", operator: "eq", value: "bar"}]
      )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{
               current_status: "pending",
               approvals: []
             } = Requests.get_grant_request!(request_id, claims)
    end

    test "will not create an approval of a role that is not pending approval", %{
      domain_ids: domain_ids,
      data_structure: data_structure
    } do
      %{id: admin_user_id} = CacheHelpers.insert_user(role: "admin")

      insert(:approval_rule,
        role: "invalid_role",
        user_id: admin_user_id,
        domain_ids: domain_ids,
        conditions: [%{field: "request.string", operator: "eq", value: "bar"}]
      )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{
               current_status: "pending",
               approvals: []
             } = Requests.get_grant_request!(request_id, claims)
    end

    test "approval will not be create if rule creator does not exist", %{
      domain_ids: domain_ids,
      data_structure: data_structure
    } do
      insert(:approval_rule,
        role: @approver_role,
        user_id: "-1",
        domain_ids: domain_ids,
        conditions: [%{field: "request.string", operator: "eq", value: "bar"}]
      )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{
               current_status: "pending",
               approvals: []
             } = Requests.get_grant_request!(request_id, claims)
    end

    test "does nothing if rule does not match", %{
      approver_user_id: approver_user_id,
      domain_ids: domain_ids,
      data_structure: data_structure
    } do
      insert(:approval_rule,
        role: @approver_role,
        user_id: approver_user_id,
        domain_ids: domain_ids,
        conditions: [%{field: "request.string", operator: "eq", value: "not_bar_value"}]
      )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{current_status: "pending"} = Requests.get_grant_request!(request_id, claims)
    end

    test "duplicated rule for the same role will only create approval for the first", %{
      approver_user_id: approver_user_id,
      domain_ids: domain_ids,
      data_structure: data_structure
    } do
      insert(:approval_rule,
        role: @approver_role,
        user_id: approver_user_id,
        domain_ids: domain_ids,
        comment: "RULE1",
        conditions: [%{field: "request.string", operator: "eq", value: "bar"}]
      )

      insert(:approval_rule,
        role: @approver_role,
        user_id: approver_user_id,
        domain_ids: domain_ids,
        comment: "RULE2",
        conditions: [%{field: "request.string", operator: "eq", value: "bar"}]
      )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{current_status: "approved", approvals: [%{comment: "RULE1"}]} =
               Requests.get_grant_request!(request_id, claims)
    end

    test "reject rule will reject the request", %{
      approver_user_id: approver_user_id,
      domain_ids: domain_ids,
      data_structure: data_structure
    } do
      insert(:approval_rule,
        role: @approver_role,
        user_id: approver_user_id,
        domain_ids: domain_ids,
        action: "reject",
        conditions: [%{field: "request.string", operator: "eq", value: "bar"}]
      )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{current_status: "rejected"} = Requests.get_grant_request!(request_id, claims)
    end

    test "reject rule will overcome any approval", %{
      approver_user_id: approver_user_id,
      domain_ids: domain_ids,
      data_structure: data_structure
    } do
      insert(:approval_rule,
        role: @approver_role,
        user_id: approver_user_id,
        domain_ids: domain_ids,
        conditions: [%{field: "request.string", operator: "eq", value: "bar"}]
      )

      insert(:approval_rule,
        role: @approver_role,
        user_id: approver_user_id,
        domain_ids: domain_ids,
        action: "reject",
        conditions: [%{field: "request.string", operator: "eq", value: "bar"}]
      )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{current_status: "rejected"} = Requests.get_grant_request!(request_id, claims)
    end

    test "deleting approval rule will nilify approval_rule_id", %{
      approver_user_id: approver_user_id,
      domain_ids: domain_ids,
      data_structure: data_structure
    } do
      %{id: approval_rule_id} =
        insert(:approval_rule,
          role: @approver_role,
          user_id: approver_user_id,
          domain_ids: domain_ids,
          conditions: [%{field: "request.string", operator: "eq", value: "bar"}]
        )

      %{user_id: user_id} = claims = build(:claims)

      params = %{
        type: @template_name,
        requests: [
          %{
            data_structure_id: data_structure.id,
            metadata: @valid_metadata
          }
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok, %{group: _group, requests: {_count, [request_id]}}} =
               Requests.create_grant_request_group(params)

      assert %{
               approvals: [%{approval_rule_id: ^approval_rule_id}]
             } = Requests.get_grant_request!(request_id, claims)

      approval_rule_id
      |> ApprovalRules.get!()
      |> ApprovalRules.delete()

      assert %{
               approvals: [%{approval_rule_id: nil}]
             } = Requests.get_grant_request!(request_id, claims)
    end
  end
end
