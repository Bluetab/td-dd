defmodule TdDd.Grants.AuditTest do
  use TdDd.DataCase

  alias TdCache.Redix.Stream
  alias TdDd.Grants.Requests

  @stream TdCache.Audit.stream()

  setup do
    claims = build(:claims, role: "admin")
    [claims: claims]
  end

  describe "Requests.create_approval/2" do
    setup :setup_grant_request

    test "inserts a rejected status publishes an audit event", %{
      claims: %{user_id: user_id} = claims,
      domain_id: domain_id
    } do
      %{id: system_id} = insert(:system)

      %{id: data_structure_id} =
        data_structure =
        insert(:data_structure,
          system_id: system_id,
          domain_ids: [domain_id]
        )

      insert(:data_structure_version, data_structure_id: data_structure_id)

      request =
        insert(:grant_request,
          data_structure: data_structure,
          data_structure_id: data_structure_id,
          current_status: "pending",
          domain_ids: [domain_id]
        )

      CacheHelpers.put_grant_request_approvers([
        %{user_id: user_id, domain_id: domain_id, role: "rejector"}
      ])

      params = %{role: "rejector", is_rejection: true, comment: "foo"}

      assert {:ok, %{audit: event_id}} = Requests.create_approval(claims, request, params)

      assert {:ok, [%{id: ^event_id}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)
    end
  end

  defp setup_grant_request(%{claims: %{user_id: user_id}}) do
    %{id: domain_id} = CacheHelpers.insert_domain()
    CacheHelpers.insert_user(user_id: user_id)

    [
      domain_id: domain_id,
      request: insert(:grant_request, current_status: "pending", domain_ids: [domain_id])
    ]
  end
end
