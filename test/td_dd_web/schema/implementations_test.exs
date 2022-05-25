defmodule TdDdWeb.Schema.ImplementationsTest do
  use TdDdWeb.ConnCase

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

  @unreject_implementation """
  mutation unrejectImplementation($id: ID!) {
    unrejectImplementation(id: $id) {
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

  @deprecate_implementation """
  mutation deprecateImplementation($id: ID!) {
    deprecateImplementation(id: $id) {
      id
      status
      version
      deleted_at
    }
  }
  """

  @publish_implementation_from_draft """
  mutation publishImplementationFromDraft($id: ID!) {
    publishImplementationFromDraft(id: $id) {
      id
      status
      version
    }
  }
  """

  setup_all do
    start_supervised!(TdDd.Search.MockIndexWorker)
    :ok
  end

  describe "submitImplementation mutation" do
    @tag authentication: [role: "user"]
    test "return error when user has no permissions", %{conn: conn} do
      %{id: implementation_id} = insert(:implementation)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @submit_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: ["manage_draft_implementation"]]
    test "return implementation when user has permissions", %{conn: conn, domain: domain} do
      %{id: implementation_id} = insert(:implementation, domain_id: domain.id)

      assert %{"data" => data} =
               resp =
               conn
               |> post("api/v2", %{
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

    @tag authentication: [role: "user", permissions: ["manage_draft_implementation"]]
    test "return error when user not has permissions for specific domain",
         %{conn: conn} do
      %{id: implementation_id} = insert(:implementation)

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
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
               |> post("api/v2", %{
                 "query" => @submit_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "unprocessable_entity"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "return error when the implementation is not the last", %{
      conn: conn
    } do
      insert(:implementation,
        implementation_key: "foo",
        status: "versioned",
        version: 2
      )

      %{id: draft_id} =
        insert(:implementation,
          implementation_key: "foo",
          status: "draft",
          version: 1
        )

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @submit_implementation,
                 "variables" => %{"id" => draft_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "unprocessable_entity"}] = errors
    end
  end

  describe "rejectImplementation mutation" do
    @tag authentication: [role: "user"]
    test "return error when user has no permissions", %{conn: conn} do
      %{id: implementation_id} = insert(:implementation, status: "pending_approval")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
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
               |> post("api/v2", %{
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
               |> post("api/v2", %{
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
               |> post("api/v2", %{
                 "query" => @reject_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "unprocessable_entity"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "return error when the implementation is not the last", %{
      conn: conn
    } do
      insert(:implementation,
        implementation_key: "foo",
        status: "versioned",
        version: 2
      )

      %{id: pending_approval_id} =
        insert(:implementation,
          implementation_key: "foo",
          status: "pending_approval",
          version: 1
        )

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @reject_implementation,
                 "variables" => %{"id" => pending_approval_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "unprocessable_entity"}] = errors
    end
  end

  describe "unrejectImplementation mutation" do
    @tag authentication: [role: "user"]
    test "return error when user has no permissions", %{conn: conn} do
      %{id: implementation_id} = insert(:implementation, status: "rejected")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @unreject_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: ["manage_draft_implementation"]]
    test "return implementation when user has permissions", %{conn: conn, domain: domain} do
      %{id: implementation_id} = insert(:implementation, domain_id: domain.id, status: "rejected")

      assert %{"data" => data} =
               resp =
               conn
               |> post("api/v2", %{
                 "query" => @unreject_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      implementation_id = to_string(implementation_id)

      assert %{
               "unrejectImplementation" => %{
                 "id" => ^implementation_id,
                 "status" => "pending_approval",
                 "version" => 1
               }
             } = data
    end

    @tag authentication: [role: "user", permissions: ["manage_draft_implementation"]]
    test "return error when user not has permissions for specific domain",
         %{conn: conn} do
      %{id: implementation_id} = insert(:implementation, status: "rejected")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @unreject_implementation,
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
               |> post("api/v2", %{
                 "query" => @unreject_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "unprocessable_entity"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "return error when the implementation is not the last", %{
      conn: conn
    } do
      insert(:implementation,
        implementation_key: "foo",
        status: "versioned",
        version: 2
      )

      %{id: rejected_id} =
        insert(:implementation,
          implementation_key: "foo",
          status: "rejected",
          version: 1
        )

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @unreject_implementation,
                 "variables" => %{"id" => rejected_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "unprocessable_entity"}] = errors
    end
  end

  describe "publishedImplementation mutation" do
    @tag authentication: [role: "user"]
    test "return error when user has no permissions", %{conn: conn} do
      %{id: implementation_id} = insert(:implementation, status: "pending_approval")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @publish_implementation,
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
               |> post("api/v2", %{
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
                 "version" => 1
               }
             } = data
    end

    @tag authentication: [role: "user", permissions: ["publish_implementation"]]
    test "return error when user not has permissions for specific domain",
         %{conn: conn} do
      %{id: implementation_id} = insert(:implementation, status: "pending_approval")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
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
               |> post("api/v2", %{
                 "query" => @publish_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "unprocessable_entity"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "return error when the implementation is not the last", %{
      conn: conn
    } do
      insert(:implementation,
        implementation_key: "foo",
        status: "versioned",
        version: 2
      )

      %{id: pending_approval_id} =
        insert(:implementation,
          implementation_key: "foo",
          status: "pending_approval",
          version: 1
        )

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @publish_implementation,
                 "variables" => %{"id" => pending_approval_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "unprocessable_entity"}] = errors
    end
  end

  describe "deprecateImplementation mutation" do
    @tag authentication: [role: "user"]
    test "return error when user has no permissions", %{conn: conn} do
      %{id: implementation_id} = insert(:implementation, status: "published")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @deprecate_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: ["deprecate_implementation"]]
    test "return implementation when user has permissions", %{conn: conn, domain: domain} do
      %{id: implementation_id} =
        insert(:implementation, domain_id: domain.id, status: "published")

      assert %{"data" => data} =
               resp =
               conn
               |> post("api/v2", %{
                 "query" => @deprecate_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")

      implementation_id = to_string(implementation_id)

      assert %{
               "deprecateImplementation" => %{
                 "id" => ^implementation_id,
                 "status" => "deprecated",
                 "version" => 1,
                 "deleted_at" => deleted_at
               }
             } = data

      assert deleted_at != nil
    end

    @tag authentication: [role: "user", permissions: ["deprecate_implementation"]]
    test "return error when user not has permissions for specific domain",
         %{conn: conn} do
      %{id: implementation_id} = insert(:implementation, status: "published")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @deprecate_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "return error when try submit implementation different for published", %{
      conn: conn
    } do
      %{id: implementation_id} = insert(:implementation, status: "draft")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @deprecate_implementation,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "unprocessable_entity"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "return error when the implementation is not the last", %{
      conn: conn
    } do
      insert(:implementation,
        implementation_key: "foo",
        status: "versioned",
        version: 2
      )

      %{id: published_id} =
        insert(:implementation,
          implementation_key: "foo",
          status: "rejected",
          version: 1
        )

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @deprecate_implementation,
                 "variables" => %{"id" => published_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "unprocessable_entity"}] = errors
    end
  end

  describe "publishImplementationFromDraft mutation" do
    @tag authentication: [role: "user"]
    test "return error when user has no permissions", %{conn: conn} do
      %{id: implementation_id} = insert(:implementation, status: "draft")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @publish_implementation_from_draft,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [
           role: "user",
           permissions: ["manage_draft_implementation", "publish_implementation"]
         ]
    test "return implementation when user has permissions", %{conn: conn, domain: domain} do
      %{id: implementation_id} = insert(:implementation, domain_id: domain.id, status: "draft")

      assert %{"data" => data} =
               resp =
               conn
               |> post("api/v2", %{
                 "query" => @publish_implementation_from_draft,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      implementation_id = to_string(implementation_id)

      assert %{
               "publishImplementationFromDraft" => %{
                 "id" => ^implementation_id,
                 "status" => "published",
                 "version" => 1
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: ["manage_draft_implementation", "publish_implementation"]
         ]
    test "return error when user not has permissions for specific domain",
         %{conn: conn} do
      %{id: implementation_id} = insert(:implementation, status: "draft")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @publish_implementation_from_draft,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "return error when try submit implementation different for draft", %{
      conn: conn
    } do
      %{id: implementation_id} = insert(:implementation, status: "rejected")

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @publish_implementation_from_draft,
                 "variables" => %{"id" => implementation_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "unprocessable_entity"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "return error when the implementation is not the last", %{
      conn: conn
    } do
      insert(:implementation,
        implementation_key: "foo",
        status: "versioned",
        version: 2
      )

      %{id: draft_id} =
        insert(:implementation,
          implementation_key: "foo",
          status: "draft",
          version: 1
        )

      assert %{"data" => nil, "errors" => errors} =
               conn
               |> post("api/v2", %{
                 "query" => @publish_implementation_from_draft,
                 "variables" => %{"id" => draft_id}
               })
               |> json_response(:ok)

      assert [%{"message" => "unprocessable_entity"}] = errors
    end
  end
end
