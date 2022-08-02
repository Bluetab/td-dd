defmodule TdDdWeb.Schema.DomainTest do
  use TdDdWeb.ConnCase

  @domains """
  query Domains($action: String!) {
    domains(action: $action) {
      id
      parentId
      externalId
      name
    }
  }
  """

  @domains_with_actions """
  query Domains($action: String!, $domainActions: [String!]!) {
    domains(action: $action) {
      id
      parentId
      externalId
      name
      actions(actions: $domainActions)
    }
  }
  """

  @variables %{"action" => "manageTags"}

  describe "domains query" do
    @tag authentication: [role: "user"]
    test "returns empty list when queried by user with no permissions", %{conn: conn} do
      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @domains, "variables" => @variables})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert data == %{"domains" => []}
    end

    @tag authentication: [role: "admin"]
    test "returns data when queried by admin user", %{conn: conn} do
      %{id: parent_id} = d1 = CacheHelpers.insert_domain()
      d2 = CacheHelpers.insert_domain(parent_id: parent_id)

      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @domains, "variables" => @variables})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert %{"domains" => domains} = data

      assert_lists_equal(domains, [d1, d2], &(&1 == expected(&2)))
    end

    @tag authentication: [role: "user", permissions: [:link_data_structure_tag]]
    test "returns data when queried by user with permissions", %{conn: conn, domain: domain} do
      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @domains, "variables" => @variables})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert %{"domains" => domains} = data
      assert_lists_equal(domains, [domain], &(&1 == expected(&2)))
    end

    @tag authentication: [role: "user", permissions: [:nothing]]
    test "returns only the domains with all the requested permissions", %{
      conn: conn,
      claims: claims,
      domain: domain
    } do
      one_permission_domain = CacheHelpers.insert_domain()
      two_permission_domain = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{
        manage_quality_rule_implementations: [
          domain.id,
          two_permission_domain.id,
          one_permission_domain.id
        ],
        manage_ruleless_implementations: [domain.id, two_permission_domain.id]
      })

      domain_child = CacheHelpers.insert_domain(parent_id: domain.id)

      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{
                 "query" => @domains,
                 "variables" => %{"action" => "manageRulelessImplementations"}
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert %{"domains" => domains} = data

      assert_lists_equal(
        domains,
        [domain, domain_child, two_permission_domain],
        &(&1 == expected(&2))
      )
    end

    @tag authentication: [
           role: "user",
           permissions: [
             :manage_quality_rule_implementations,
             :publish_implementation,
             :manage_segments
           ]
         ]
    test "returns the actions for specific domain for form implementation", %{
      conn: conn,
      domain: %{id: parent_domain_id} = domain,
      claims: claims
    } do
      %{id: domain_one_id} = one_permission_domain = CacheHelpers.insert_domain()

      %{id: domain_two_id} = two_permission_domain = CacheHelpers.insert_domain()

      %{id: domain_child_id} = CacheHelpers.insert_domain(parent_id: domain.id)

      [parent_domain_id, domain_one_id, domain_two_id, domain_child] =
        Enum.map([parent_domain_id, domain_one_id, domain_two_id, domain_child_id], fn id ->
          to_string(id)
        end)

      CacheHelpers.put_session_permissions(claims, %{
        manage_quality_rule_implementations: [
          domain.id,
          two_permission_domain.id,
          one_permission_domain.id
        ],
        publish_implementation: [two_permission_domain.id, one_permission_domain.id],
        manage_segments: [one_permission_domain.id]
      })

      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{
                 "query" => @domains_with_actions,
                 "variables" => %{
                   "action" => "manageImplementations",
                   "domainActions" => [
                     "manageSegments",
                     "publishImplementation",
                     "manageRulelessImplementations",
                     "manageImplementations",
                     "unknownActions"
                   ]
                 }
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")

      domains_actions =
        Map.new(data["domains"], fn %{"actions" => actions, "id" => id} -> {id, actions} end)

      assert %{
               parent_domain_id => ["manageImplementations"],
               domain_one_id => [
                 "publishImplementation",
                 "manageSegments",
                 "manageImplementations"
               ],
               domain_two_id => ["publishImplementation", "manageImplementations"],
               domain_child => ["manageImplementations"]
             } == domains_actions
    end
  end

  defp expected(%{} = d) do
    d
    |> Map.put_new(:parent_id, nil)
    |> Map.take([:id, :parent_id, :external_id, :name])
    |> Map.new(fn
      {k, nil} -> {Inflex.camelize(k, :lower), nil}
      {k, v} -> {Inflex.camelize(k, :lower), to_string(v)}
    end)
  end
end
