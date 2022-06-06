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

  @publish_implementation """
  mutation publishImplementation($id: ID!) {
    publishImplementation(id: $id) {
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

      assert [%{"message" => "forbidden"}] = errors
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

      assert [%{"message" => "forbidden"}] = errors
    end
  end

  describe "publishImplementation mutation" do
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
      %{implementation_key: key} = insert(:implementation, status: :published, version: 4)

      %{id: implementation_id} =
        insert(:implementation,
          domain_id: domain.id,
          status: "pending_approval",
          implementation_key: key,
          version: 0
        )

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

      assert [%{"message" => "forbidden"}] = errors
    end
  end
end
