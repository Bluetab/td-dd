defmodule TdDd.GrantRequests.AuditTest do
  use TdDd.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCore.Search.IndexWorkerMock
  alias TdDd.Grants.Requests
  alias TdDd.Grants.Statuses

  @stream TdCache.Audit.stream()

  @template_name "grant_request_test_template"
  @valid_metadata %{"list" => "one", "string" => "bar"}

  setup do
    claims = build(:claims, role: "admin")
    IndexWorkerMock.clear()

    on_exit(fn ->
      Redix.del!(@stream)
    end)

    [claims: claims]
  end

  describe "Requests.create_approval/2" do
    setup :setup_grant_request

    test "rejected status insertion publishes an audit event", %{
      claims: %{user_id: user_id} = claims,
      domain_id: domain_id,
      data_structure: data_structure
    } do
      request =
        insert(:grant_request,
          data_structure: data_structure,
          data_structure_id: data_structure.id,
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

  describe "Requests.bulk_create_approvals/3" do
    setup :setup_grant_request

    test "rejected status insertion publishes an audit event", %{
      claims: %{user_id: user_id} = claims,
      domain_id: domain_id,
      data_structure: data_structure
    } do
      grant_requests =
        Enum.map(1..3, fn _ ->
          insert(:grant_request,
            data_structure: data_structure,
            data_structure_id: data_structure.id,
            current_status: "pending",
            domain_ids: [domain_id]
          )
        end)

      CacheHelpers.put_grant_request_approvers([
        %{user_id: user_id, domain_id: domain_id, role: "rejector"}
      ])

      params = %{role: "rejector", is_rejection: true, comment: "foo"}

      assert {:ok, %{audit: event_ids}} =
               Requests.bulk_create_approvals(claims, grant_requests, params)

      for event_id <- event_ids do
        assert {:ok, [%{id: ^event_id, event: "grant_request_rejection"}]} =
                 Stream.range(:redix, @stream, event_id, event_id, transform: :range)
      end
    end
  end

  describe "Statuses.create_grant_request_status/3" do
    setup :setup_grant_request

    test "processing status insertion publishes an audit event", %{
      claims: %{user_id: user_id},
      data_structure: data_structure,
      domain_id: domain_id
    } do
      request =
        insert(:grant_request,
          data_structure: data_structure,
          data_structure_id: data_structure.id,
          current_status: "approved",
          domain_ids: [domain_id]
        )

      assert {:ok,
              %{
                audit: event_id,
                grant_request_status: %{id: grant_request_status_id}
              }} = Statuses.create_grant_request_status(request, "processing", user_id)

      resource_id = "#{grant_request_status_id}"

      assert {
               :ok,
               [
                 %{
                   id: ^event_id,
                   event: "grant_request_status_process_start",
                   resource_id: ^resource_id,
                   resource_type: "grant_request_status",
                   payload: payload
                 }
               ]
             } = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert %{
               "status" => "processing",
               "grant_request" => %{
                 "data_structure" => %{"current_version" => %{"name" => dsv_name}}
               }
             } = Jason.decode!(payload)

      assert dsv_name =~ "data_structure_version_name"
    end
  end

  describe "Requests.create_grant_request_group/3" do
    setup do
      [template: CacheHelpers.insert_template(name: @template_name)]
    end

    test "grant request group insertion publishes an audit event", %{
      claims: %{user_id: user_id} = claims
    } do
      [
        domain_parent_id: domain_1_parent_id,
        domain_id: domain_id_1,
        data_structure: data_structure_1
      ] = setup_grant_request(%{claims: claims})

      [
        domain_parent_id: domain_2_parent_id,
        domain_id: domain_id_2,
        data_structure: data_structure_2
      ] = setup_grant_request(%{claims: claims})

      insert(:grant, data_structure_id: data_structure_1.id)
      insert(:grant, data_structure_id: data_structure_2.id)

      params = %{
        type: @template_name,
        requests: [
          %{data_structure_id: data_structure_1.id, metadata: @valid_metadata},
          %{data_structure_id: data_structure_2.id, metadata: @valid_metadata}
        ],
        user_id: user_id,
        created_by_id: user_id
      }

      assert {:ok,
              %{
                audit: event_id,
                group: %{id: grant_request_group_id, requests: _grant_requests}
              }} = Requests.create_grant_request_group(params)

      resource_id = "#{grant_request_group_id}"

      assert {
               :ok,
               [
                 %{
                   id: ^event_id,
                   event: "grant_request_group_creation",
                   resource_id: ^resource_id,
                   resource_type: "grant_request_groups",
                   payload: payload
                 }
               ]
             } = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert %{
               "domain_ids" => [
                 [^domain_id_2, ^domain_2_parent_id],
                 [^domain_id_1, ^domain_1_parent_id]
               ],
               "requests" => [
                 %{
                   "id" => _grant_request_1_id,
                   "data_structure" => %{"current_version" => %{"name" => dsv_1_name}}
                 },
                 %{
                   "id" => _grant_request_2_id,
                   "data_structure" => %{"current_version" => %{"name" => dsv_2_name}}
                 }
               ]
             } = Jason.decode!(payload)

      assert dsv_1_name =~ "data_structure_version_name"
      assert dsv_2_name =~ "data_structure_version_name"
    end
  end

  defp setup_grant_request(%{claims: %{user_id: user_id}}) do
    %{id: domain_id_parent} = CacheHelpers.insert_domain()
    %{id: domain_id} = CacheHelpers.insert_domain(parent_id: domain_id_parent)
    CacheHelpers.insert_user(user_id: user_id)

    %{id: system_id} = insert(:system)

    %{id: data_structure_id} =
      data_structure =
      insert(:data_structure,
        system_id: system_id,
        domain_ids: [domain_id]
      )

    insert(:data_structure_version, data_structure_id: data_structure_id)

    [
      domain_parent_id: domain_id_parent,
      domain_id: domain_id,
      data_structure: data_structure
    ]
  end
end
