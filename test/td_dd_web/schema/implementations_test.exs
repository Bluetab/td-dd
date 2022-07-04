defmodule TdDdWeb.Schema.ImplementationsTest do
  use TdDdWeb.ConnCase
  import TdDd.TestOperators

  @submit_implementation """
  mutation SubmitImplementation($id: ID!) {
    submitImplementation(id: $id) {
      id
      status
      version
    }
  }

  """
  @reject_implementation """
  mutation rejectImplementation($id: ID!) {
    rejectImplementation(id: $id) {
      id
      status
      version
    }
  }
  """

  @publish_implementation """
  mutation publishImplementation($id: ID!) {
    publishImplementation(id: $id) {
      id
      status
      version
    }
  }
  """

  @implementation_with_versions_query """
  query Implementation($id: ID!) {
    implementation(id: $id) {
      id,
      implementation_key,
      version,
      versions {
        id
        implementation_key
        version
      }
    }
  }
  """

  @implementation_with_results_query """
  query Implementation($id: ID!) {
    implementation(id: $id) {
      id,
      results {
        id
      }
    }
  }
  """

  @implementation_with_quality_event_query """
  query Implementation($id: ID!) {
    implementation(id: $id) {
      id,
      last_quality_event {
        message
        type
        inserted_at
      }
    }
  }
  """

  @implementation_with_results_and_segments_query """
  query Implementation($id: ID!) {
    implementation(id: $id) {
      id,
      results {
        id,
        has_segments
      }
    }
  }
  """

  @implementation_with_results_and_remediation_query """
  query Implementation($id: ID!) {
    implementation(id: $id) {
      id,
      results {
        id,
        has_remediation
      }
    }
  }
  """

  @implementation_with_versions_results_query """
  query Implementation($id: ID!) {
    implementation(id: $id) {
      id,
      versions {
        results {
          id
        }
      }
    }
  }
  """

  setup_all do
    start_supervised!(TdDd.Search.MockIndexWorker)
    :ok
  end

  describe "Implementations query" do
    @tag authentication: [role: "admin"]
    test "return last result event when is requested", %{conn: conn} do
      %{id: implementation_id} = insert(:implementation)

      %{id: execution_id} = insert(:execution, implementation_id: implementation_id)

      params = %{
        message: "foo",
        inserted_at: "2022-06-30T14:05:59.889855Z",
        type: "FAILED",
        execution_id: execution_id
      }

      insert(:quality_event, params)

      assert %{"data" => %{"implementation" => %{"last_quality_event" => last_quality_event}}} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_with_quality_event_query,
                 "variables" => %{id: implementation_id}
               })
               |> json_response(:ok)

      assert params
             |> Map.Helpers.stringify_keys()
             |> Map.take(Map.keys(last_quality_event)) == last_quality_event
    end

    @tag authentication: [role: "admin"]
    test "return version when requested", %{conn: conn} do
      %{id: implementation_id} = insert(:implementation)

      assert %{"data" => %{"implementation" => implementation}} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_with_versions_query,
                 "variables" => %{id: implementation_id}
               })
               |> json_response(:ok)

      id = to_string(implementation_id)
      assert %{"versions" => [%{"id" => ^id}]} = implementation
    end

    @tag authentication: [role: "admin"]
    test "return sorted versions of an implementation", %{conn: conn} do
      %{id: id1, implementation_ref: ref} =
        insert(:implementation, status: :versioned, version: 1)

      %{id: id2} = insert(:implementation, implementation_ref: ref, status: :draft, version: 3)

      %{id: id3} =
        insert(:implementation, implementation_ref: ref, status: :published, version: 2)

      assert %{"data" => %{"implementation" => implementation}} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_with_versions_query,
                 "variables" => %{id: id2}
               })
               |> json_response(:ok)

      [sid1, sid2, sid3] = [id1, id2, id3] |> Enum.map(&to_string/1)

      assert %{
               "versions" => [
                 %{
                   "version" => 3,
                   "id" => ^sid2
                 },
                 %{
                   "version" => 2,
                   "id" => ^sid3
                 },
                 %{
                   "version" => 1,
                   "id" => ^sid1
                 }
               ]
             } = implementation
    end

    @tag authentication: [role: "admin"]
    test "get results of an implementation", %{conn: conn} do
      %{id: implementation_id} = implementation = insert(:implementation)
      %{id: rule_result_id_1} = insert(:rule_result, implementation: implementation)
      %{id: rule_result_id_2} = insert(:rule_result, implementation: implementation)
      %{id: rule_result_id_3} = insert(:rule_result, implementation: implementation)

      assert %{"data" => %{"implementation" => implementation}} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_with_results_query,
                 "variables" => %{id: implementation_id}
               })
               |> json_response(:ok)

      assert [
               %{"id" => to_string(rule_result_id_1)},
               %{"id" => to_string(rule_result_id_2)},
               %{"id" => to_string(rule_result_id_3)}
             ]
             <|> Map.get(implementation, "results")
    end

    @tag authentication: [role: "admin"]
    test "get results of an implementation and its versions", %{conn: conn} do
      %{implementation_ref: ref} =
        implementation_1 = insert(:implementation, status: :versioned, version: 1)

      %{id: id2} =
        implementation_2 =
        insert(:implementation, implementation_ref: ref, status: :draft, version: 3)

      implementation_3 =
        insert(:implementation, implementation_ref: ref, status: :published, version: 2)

      %{id: rule_result_id_1_1} = insert(:rule_result, implementation: implementation_1)
      %{id: rule_result_id_1_2} = insert(:rule_result, implementation: implementation_1)
      %{id: rule_result_id_2_1} = insert(:rule_result, implementation: implementation_2)
      %{id: rule_result_id_3_1} = insert(:rule_result, implementation: implementation_3)
      %{id: rule_result_id_3_2} = insert(:rule_result, implementation: implementation_3)
      %{id: rule_result_id_3_3} = insert(:rule_result, implementation: implementation_3)

      assert %{"data" => %{"implementation" => implementation}} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_with_versions_results_query,
                 "variables" => %{id: id2}
               })
               |> json_response(:ok)

      [
        str_rule_result_id_1_1,
        str_rule_result_id_1_2,
        str_rule_result_id_2_1,
        str_rule_result_id_3_1,
        str_rule_result_id_3_2,
        str_rule_result_id_3_3
      ] =
        [
          rule_result_id_1_1,
          rule_result_id_1_2,
          rule_result_id_2_1,
          rule_result_id_3_1,
          rule_result_id_3_2,
          rule_result_id_3_3
        ]
        |> Enum.map(&to_string/1)

      assert %{
               "versions" => [
                 %{
                   "results" => [
                     %{"id" => ^str_rule_result_id_2_1}
                   ]
                 },
                 %{
                   "results" => [
                     %{"id" => ^str_rule_result_id_3_1},
                     %{"id" => ^str_rule_result_id_3_2},
                     %{"id" => ^str_rule_result_id_3_3}
                   ]
                 },
                 %{
                   "results" => [
                     %{"id" => ^str_rule_result_id_1_1},
                     %{"id" => ^str_rule_result_id_1_2}
                   ]
                 }
               ]
             } = implementation
    end

    @tag authentication: [role: "admin"]
    test "get results of an implementation with has_segmentation boolean", %{conn: conn} do
      %{id: implementation_id} = implementation = insert(:implementation)
      %{id: rule_result_1} = insert(:rule_result, implementation: implementation)
      %{id: rule_result_2} = insert(:rule_result, implementation: implementation)
      %{id: parent_id} = insert(:rule_result, implementation: implementation)
      insert(:segment_result, parent_id: parent_id)
      insert(:segment_result, parent_id: parent_id)

      assert %{"data" => %{"implementation" => %{"results" => results}}} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_with_results_and_segments_query,
                 "variables" => %{id: implementation_id}
               })
               |> json_response(:ok)

      assert [
               %{"has_segments" => false, "id" => to_string(rule_result_1)},
               %{"has_segments" => false, "id" => to_string(rule_result_2)},
               %{"has_segments" => true, "id" => to_string(parent_id)}
             ] == results
    end

    @tag authentication: [role: "admin"]
    test "get results of an implementation with has_remediation boolean", %{conn: conn} do
      %{id: implementation_id} = implementation = insert(:implementation)
      %{id: rule_result_1} = insert(:rule_result, implementation: implementation)
      %{id: rule_result_2} = insert(:rule_result, implementation: implementation)
      insert(:remediation, rule_result_id: rule_result_1)

      assert %{"data" => %{"implementation" => %{"results" => results}}} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_with_results_and_remediation_query,
                 "variables" => %{id: implementation_id}
               })
               |> json_response(:ok)

      assert [
               %{"has_remediation" => true, "id" => to_string(rule_result_1)},
               %{"has_remediation" => false, "id" => to_string(rule_result_2)}
             ] == results
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_rule"]
         ]
    test "a user with permissions can get versions of an implementation", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{id: implementation_id} = insert(:implementation, domain_id: domain_id)

      assert %{"data" => %{"implementation" => implementation}} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_with_versions_query,
                 "variables" => %{id: implementation_id}
               })
               |> json_response(:ok)

      id = to_string(implementation_id)
      assert %{"versions" => [%{"id" => ^id}]} = implementation
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_rule"]
         ]
    test "a user without permissions can not get versions of an implementation", %{conn: conn} do
      %{id: implementation_id} = insert(:implementation)

      assert %{"errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @implementation_with_versions_query,
                 "variables" => %{id: implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end
  end

  describe "submitImplementation mutation" do
    @tag authentication: [role: "user"]
    test "return error when user has no permissions", %{conn: conn} do
      %{id: implementation_id} = insert(:implementation)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @submit_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [
           role: "user",
           permissions: ["view_quality_rule", "manage_quality_rule_implementations"]
         ]
    test "return implementation when user has permissions", %{conn: conn, domain: domain} do
      %{id: implementation_id} = insert(:implementation, domain_id: domain.id, segments: [])

      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{
                 "query" => @submit_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      implementation_id = to_string(implementation_id)

      assert %{
               "submitImplementation" => %{
                 "id" => ^implementation_id,
                 "status" => "pending_approval",
                 "version" => 1
               }
             } = data
    end

    @tag authentication: [role: "user", permissions: ["view_quality_rule"]]
    test "return error when user not has permissions for specific domain",
         %{conn: conn} do
      %{id: implementation_id} = insert(:implementation)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @submit_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "return error when try submit implementation different for draft", %{
      conn: conn
    } do
      %{id: implementation_id} = insert(:implementation, status: "pending_approval")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @submit_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end
  end

  describe "rejectImplementation mutation" do
    @tag authentication: [role: "user"]
    test "return error when user has no permissions", %{conn: conn} do
      %{id: implementation_id} = insert(:implementation, status: "pending_approval")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @reject_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: ["publish_implementation"]]
    test "return implementation when user has permissions", %{conn: conn, domain: domain} do
      %{id: implementation_id} =
        insert(:implementation, domain_id: domain.id, status: "pending_approval")

      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{
                 "query" => @reject_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      implementation_id = to_string(implementation_id)

      assert %{
               "rejectImplementation" => %{
                 "id" => ^implementation_id,
                 "status" => "rejected",
                 "version" => 1
               }
             } = data
    end

    @tag authentication: [role: "user", permissions: ["reject_implementation"]]
    test "return error when user not has permissions for specific domain",
         %{conn: conn} do
      %{id: implementation_id} = insert(:implementation, status: "pending_approval")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @reject_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "return error when try submit implementation different for pending_approval",
         %{
           conn: conn
         } do
      %{id: implementation_id} = insert(:implementation, status: "published")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @reject_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end
  end

  describe "publishImplementation mutation" do
    @tag authentication: [role: "user"]
    test "return error when user has no permissions", %{conn: conn} do
      %{id: implementation_id} = insert(:implementation, status: "pending_approval")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @publish_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: ["publish_implementation"]]
    test "return implementation when user has permissions", %{conn: conn, domain: domain} do
      %{implementation_key: key, implementation_ref: implementation_ref} =
        insert(:implementation, status: :published, version: 4)

      %{id: implementation_id} =
        insert(:implementation,
          domain_id: domain.id,
          status: "pending_approval",
          implementation_key: key <> "_dif_key",
          version: 0,
          implementation_ref: implementation_ref
        )

      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{
                 "query" => @publish_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      implementation_id = to_string(implementation_id)

      assert %{
               "publishImplementation" => %{
                 "id" => ^implementation_id,
                 "status" => "published",
                 "version" => 5
               }
             } = data
    end

    @tag authentication: [role: "user", permissions: ["publish_implementation"]]
    test "return error when user not has permissions for specific domain",
         %{conn: conn} do
      %{id: implementation_id} = insert(:implementation, status: "pending_approval")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @publish_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "return error when try submit implementation different for pending_approval",
         %{
           conn: conn
         } do
      %{id: implementation_id} = insert(:implementation, status: "rejected")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @publish_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end
  end
end
