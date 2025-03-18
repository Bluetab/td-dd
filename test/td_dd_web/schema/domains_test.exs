defmodule TdDdWeb.Schema.DomainTest do
  use TdDdWeb.ConnCase

  import TdDd.TestOperators

  @domain_with_actions """
  query Domain($id: ID!, $actions: [String!]!) {
    domain(id: $id) {
      id
      actions(actions: $actions)
    }
  }
  """

  @domains """
  query Domains($action: String!, $domainActions: [String!]) {
    domains(action: $action) {
      id
      parentId
      externalId
      name
      actions(actions: $domainActions)
    }
  }
  """

  @has_any_domain """
  query HasAnyDomain($action: String!) {
    hasAnyDomain(action: $action)
  }
  """

  @domains_with_ids """
  query Domains($action: String!, $domainActions: [String!], $ids: [ID!]) {
    domains(action: $action, ids: $ids) {
      id
      parentId
      externalId
      name
      actions(actions: $domainActions)
    }
  }
  """

  @domain_with_parent """
  query Domain($id: ID!, $actions: [String!]!) {
    domain(id: $id) {
      id
      actions(actions: $actions)
      parents {
        id
      }
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

    @tag authentication: [role: "user", permissions: [:nothing]]
    test "returns specific domains queried by user with permissions", %{
      conn: conn,
      claims: claims
    } do
      %{id: domain_id_1} = CacheHelpers.insert_domain()
      %{id: domain_id_2} = CacheHelpers.insert_domain()
      %{id: domain_id_3} = CacheHelpers.insert_domain()
      %{id: domain_children_2} = CacheHelpers.insert_domain(parent_id: domain_id_2)

      CacheHelpers.put_session_permissions(claims, %{
        link_data_structure_tag: [
          domain_id_1,
          domain_id_2,
          domain_id_3,
          domain_children_2
        ]
      })

      [domain_id_2, domain_id_3, domain_children_2] =
        Enum.map([domain_id_2, domain_id_3, domain_children_2], fn id ->
          to_string(id)
        end)

      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{
                 "query" => @domains_with_ids,
                 "variables" => %{
                   "action" => "manageTags",
                   "domainActions" => ["manageTags"],
                   "ids" => [domain_id_2, domain_id_3]
                 }
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")

      domains_actions =
        Map.new(data["domains"], fn %{"actions" => actions, "id" => id} -> {id, actions} end)

      assert %{
               domain_id_2 => ["manageTags"],
               domain_id_3 => ["manageTags"],
               domain_children_2 => ["manageTags"]
             } == domains_actions
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
    test "returns the actions for a list of domains", %{
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
                 "query" => @domains,
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

    @tag authentication: [role: "admin"]
    test "returns list of domains for action viewLinage", %{
      conn: conn
    } do
      %{id: domain_id} = CacheHelpers.insert_domain()
      CacheHelpers.insert_domain()

      domain_str_id = to_string(domain_id)

      contains = %{"foo" => ["bar", "baz"], "xyz" => ["x", "y"]}
      depends = [{"bar", "baz"}, {"x", "y"}]

      groups =
        Enum.map(contains, fn {parent, _chidren} ->
          insert(:node,
            external_id: parent,
            type: "Group"
          )
        end)

      resources =
        depends
        |> Enum.flat_map(fn {from, to} -> [from, to] end)
        |> Enum.uniq()
        |> Enum.map(fn external_id ->
          insert(:node,
            external_id: external_id,
            type: "Resource"
          )
        end)

      nodes = groups ++ resources

      insert(:unit,
        domain_id: domain_id,
        nodes: Enum.filter(nodes, &(&1.external_id in ["foo", "bar", "baz"]))
      )

      assert %{"data" => %{"domains" => domains}} =
               resp =
               conn
               |> post("/api/v2", %{
                 "query" => @domains,
                 "variables" => %{"action" => "viewLineage"}
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert Enum.count(domains) == 1
      assert [%{"id" => ^domain_str_id}] = domains
    end

    @tag authentication: [
           role: "user",
           permissions: [
             :manage_quality_rule_implementations,
             :publish_implementation,
             :manage_segments
           ]
         ]
    test "returns the actions for specific domain", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      assert %{"data" => %{"domain" => domain}} =
               resp =
               conn
               |> post("/api/v2", %{
                 "query" => @domain_with_actions,
                 "variables" => %{
                   "actions" => ["manageImplementations"],
                   "id" => to_string(domain_id)
                 }
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")

      assert %{"actions" => ["manageImplementations"], "id" => to_string(domain_id)} == domain
    end

    @tag authentication: [
           role: "user",
           permissions: [:write_quality_controls]
         ]
    test "returns true if user has any permission", %{conn: conn} do
      assert %{"data" => %{"hasAnyDomain" => true}} =
               resp =
               conn
               |> post("/api/v2", %{
                 "query" => @has_any_domain,
                 "variables" => %{
                   "action" => "createQualityControls"
                 }
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
    end

    @tag authentication: [
           role: "user"
         ]
    test "returns false if user has no permission", %{conn: conn} do
      assert %{"data" => %{"hasAnyDomain" => false}} =
               resp =
               conn
               |> post("/api/v2", %{
                 "query" => @has_any_domain,
                 "variables" => %{
                   "action" => "createQualityControls"
                 }
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
    end

    @tag authentication: [role: "admin"]
    test "returns the domain with parent", %{conn: conn} do
      %{id: grandad_domain_id} = grandad_domain = CacheHelpers.insert_domain()

      %{id: father_domain_id} =
        father_domain =
        CacheHelpers.insert_domain(parent_id: grandad_domain_id, parents: [grandad_domain])

      %{id: child_domain_id} =
        CacheHelpers.insert_domain(parent_id: father_domain_id, parents: [father_domain])

      assert %{"data" => %{"domain" => domain}} =
               resp =
               conn
               |> post("/api/v2", %{
                 "query" => @domain_with_parent,
                 "variables" => %{
                   "actions" => ["manageImplementations"],
                   "id" => to_string(child_domain_id)
                 }
               })
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")

      str_father_domain_id = to_string(father_domain_id)
      str_grandad_domain_id = to_string(grandad_domain_id)
      str_child_domain_id = to_string(child_domain_id)

      assert %{
               "actions" => ["manageImplementations"],
               "id" => ^str_child_domain_id,
               "parents" => parents
             } = domain

      assert [%{"id" => str_grandad_domain_id}, %{"id" => str_father_domain_id}] ||| parents
    end
  end

  defp expected(%{} = d) do
    d
    |> Map.put_new(:actions, [])
    |> Map.put_new(:parent_id, nil)
    |> Map.take([:id, :parent_id, :external_id, :name, :actions])
    |> Map.new(fn
      {k, nil} -> {Inflex.camelize(k, :lower), nil}
      {k, []} -> {Inflex.camelize(k, :lower), []}
      {k, v} -> {Inflex.camelize(k, :lower), to_string(v)}
    end)
  end
end
