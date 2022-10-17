defmodule TdDdWeb.Schema.GrantRequestsTest do
  use TdDdWeb.ConnCase

  @grant_request_query """
  query LatestGrantRequest($id: ID!) {
    latestGrantRequest(dataStructureId: $id) {
      id
      dataStructureId
      domainIds
      group {
        id
        grant {
          id
          startDate
          endDate
        }
      }
      status {
        id
        status
        reason
      }
    }
  }
  """

  describe "Grant request query" do
    @tag authentication: [role: "admin"]
    test "return owns grant request by structure_id", %{
      conn: conn,
      claims: %{user_id: user_id} = _claims
    } do
      %{id: domain_id} = CacheHelpers.insert_domain()

      %{id: data_structure_id} = data_structure = insert(:data_structure, domain_ids: [domain_id])

      %{id: grant_id, start_date: start_date, end_date: end_date} =
        insert(:grant,
          data_structure_id: data_structure_id
        )

      %{id: group_id} =
        group = build(:grant_request_group, user_id: user_id, modification_grant_id: grant_id)

      %{id: grant_request_id} =
        insert(:grant_request,
          group: group,
          data_structure: data_structure,
          data_structure_id: data_structure_id,
          domain_ids: [domain_id]
        )

      insert(:grant_request_status,
        grant_request_id: grant_request_id,
        status: "pending",
        reason: "status_pending"
      )

      %{id: status_id, reason: reason, status: status} =
        insert(:grant_request_status,
          grant_request_id: grant_request_id,
          status: "approved",
          reason: "status_approved"
        )

      insert(:grant,
        data_structure_id: data_structure_id
      )

      %{id: other_user_id} = CacheHelpers.insert_user()

      insert(:grant_request,
        group: build(:grant_request_group, user_id: other_user_id),
        data_structure: data_structure,
        data_structure_id: data_structure_id,
        domain_ids: [domain_id]
      )

      assert %{"data" => %{"latestGrantRequest" => grant_request}} =
               conn
               |> post("/api/v2", %{
                 "query" => @grant_request_query,
                 "variables" => %{"id" => data_structure_id}
               })
               |> json_response(:ok)

      assert grant_request == %{
               "dataStructureId" => to_string(data_structure_id),
               "domainIds" => [to_string(domain_id)],
               "group" => %{
                 "grant" => %{
                   "endDate" => Date.to_iso8601(end_date),
                   "id" => to_string(grant_id),
                   "startDate" => Date.to_iso8601(start_date)
                 },
                 "id" => to_string(group_id)
               },
               "id" => to_string(grant_request_id),
               "status" => %{
                 "id" => to_string(status_id),
                 "reason" => reason,
                 "status" => status
               }
             }
    end

    @tag authentication: [role: "user", permissions: ["view_data_structure"]]
    test "user with view_data_structure can query their own grant request by structure_id", %{
      conn: conn,
      domain: %{id: domain_id},
      claims: %{user_id: user_id} = _claims
    } do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain_id])

      %{grant_request_id: grant_request_id} =
        insert(:grant_request_status,
          grant_request:
            build(:grant_request,
              group: build(:grant_request_group, user_id: user_id),
              data_structure_id: data_structure_id,
              domain_ids: [domain_id]
            ),
          status: "approved",
          reason: "status_approved"
        )

      assert %{"data" => %{"latestGrantRequest" => grant_request}} =
               conn
               |> post("/api/v2", %{
                 "query" => @grant_request_query,
                 "variables" => %{"id" => data_structure_id}
               })
               |> json_response(:ok)

      assert %{"id" => id} = grant_request
      assert id == "#{grant_request_id}"
    end

    @tag authentication: [role: "user", permissions: ["view_data_structure"]]
    test "user with view_data_structure can query lastest grant request by structure_id even if nil",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain_id])

      assert %{"data" => %{"latestGrantRequest" => nil}} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @grant_request_query,
                 "variables" => %{"id" => data_structure_id}
               })
               |> json_response(:ok)

      refute Map.has_key?(response, "errors")
    end

    @tag authentication: [role: "admin"]
    test "data_structure without grant requests will return nil and no errors", %{
      conn: conn
    } do
      %{id: data_structure_id} = insert(:data_structure)

      assert %{"data" => %{"latestGrantRequest" => nil}} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @grant_request_query,
                 "variables" => %{"id" => data_structure_id}
               })
               |> json_response(:ok)

      refute Map.has_key?(response, "errors")
    end

    @tag authentication: [role: "non_admin"]
    test "returns forbidden if user has no permissions", %{
      conn: conn
    } do
      %{id: data_structure_id} = insert(:data_structure)

      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @grant_request_query,
                 "variables" => %{"id" => data_structure_id}
               })
               |> json_response(:ok)

      assert data == %{"latestGrantRequest" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end
  end
end
