defmodule TdDd.Grants.RequestsTest do
  use TdDd.DataCase

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
      %{user_id: approver_user_id, domain_id: domain_id, role: @approver_role}
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
               Requests.create_grant_request_group(params, claims)

      assert %{current_status: "approved"} = Requests.get_grant_request!(request_id, claims)
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
               Requests.create_grant_request_group(params, claims)

      assert %{current_status: "pending"} = Requests.get_grant_request!(request_id, claims)
    end

    test "duplicated rule for the same role will only create approal for the first", %{
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
               Requests.create_grant_request_group(params, claims)

      assert %{current_status: "approved", approvals: [%{comment: "RULE1"}]} =
               Requests.get_grant_request!(request_id, claims)
    end
  end
end
