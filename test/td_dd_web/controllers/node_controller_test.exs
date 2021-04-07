defmodule TdDdWeb.NodeControllerTest do
  use TdDdWeb.ConnCase
  use TdDd.GraphDataCase

  alias TdCache.TaxonomyCache
  alias TdDd.Lineage.GraphData
  alias TdDd.Lineage.GraphData.State

  setup_all do
    start_supervised(GraphData)
    :ok
  end

  setup %{conn: conn} = tags do
    GraphData.state(state: setup_state(tags))
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "NodeController" do
    @tag authentication: [role: "admin"]
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz"}]
    test "index returns the top-level groups and parent nil", %{conn: conn} do
      conn = get(conn, Routes.node_path(conn, :index))

      assert [%{"parent" => nil, "groups" => [group]}] = json_response(conn, 200)["data"]

      assert %{"external_id" => "foo", "name" => "foo"} = group
    end

    @tag authentication: [role: "admin"]
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz"}]
    test "show returns a list including the child resources of the specified group", %{conn: conn} do
      conn = get(conn, Routes.node_path(conn, :show, "foo"))

      assert [first, second] = json_response(conn, 200)["data"]

      assert %{"groups" => [group], "parent" => nil} = first
      assert %{"external_id" => "foo", "name" => "foo"} = group

      assert %{"parent" => "foo", "resources" => resources} = second
      assert %{"bar" => _bar, "baz" => _baz} = Enum.group_by(resources, & &1["external_id"])
      assert %{"bar" => _bar, "baz" => _baz} = Enum.group_by(resources, & &1["name"])
      assert %{"foo_type" => [_bar, _baz]} = Enum.group_by(resources, & &1["type"])
    end

    @tag authentication: [user_name: "non_admin_user"]
    @tag contains: %{"foo" => ["bar", "baz"], "xyz" => ["x", "y"]}
    @tag depends: [{"bar", "baz"}, {"x", "y"}]
    test "will filter groups depending on user permissions over domains", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      domain_id = :rand.uniform(1_000_000)
      TaxonomyCache.put_domain(%{name: "domain", id: domain_id, updated_at: DateTime.utc_now()})

      MockPermissionResolver.create_acl_entry(%{
        principal_id: user_id,
        principal_type: "user",
        resource_id: domain_id,
        resource_type: "domain",
        permissions: []
      })

      unit = insert(:unit, domain_id: domain_id)

      insert(
        :node,
        external_id: "foo",
        units: [unit]
      )

      insert(
        :node,
        external_id: "bar",
        units: [unit]
      )

      insert(
        :node,
        external_id: "baz",
        units: [unit]
      )

      domain_id = :rand.uniform(1_000_000)
      TaxonomyCache.put_domain(%{name: "domain1", id: domain_id, updated_at: DateTime.utc_now()})

      MockPermissionResolver.create_acl_entry(%{
        principal_id: user_id,
        principal_type: "user",
        resource_id: domain_id,
        resource_type: "domain",
        permissions: [:view_data_structure, :view_lineage]
      })

      unit = insert(:unit, domain_id: domain_id)

      insert(
        :node,
        external_id: "xyz",
        units: [unit]
      )

      insert(
        :node,
        external_id: "x",
        units: [unit]
      )

      insert(
        :node,
        external_id: "y",
        units: [unit]
      )

      conn = get(conn, Routes.node_path(conn, :index))
      assert [%{"parent" => nil, "groups" => [group]}] = json_response(conn, 200)["data"]

      assert %{"external_id" => "xyz", "name" => "xyz"} = group
    end

    @tag authentication: [user_name: "non_admin_user"]
    @tag contains: %{"foo" => ["bar", "baz"]}
    @tag depends: [{"bar", "baz"}]
    test "will filter a group if a user has not permissions over any of the group's permissions",
         %{
           conn: conn,
           claims: %{user_id: user_id}
         } do
      domain_id = :rand.uniform(1_000_000)
      TaxonomyCache.put_domain(%{name: "domain", id: domain_id, updated_at: DateTime.utc_now()})

      MockPermissionResolver.create_acl_entry(%{
        principal_id: user_id,
        principal_type: "user",
        resource_id: domain_id,
        resource_type: "domain",
        permissions: []
      })

      unit = insert(:unit, domain_id: domain_id)

      insert(
        :node,
        external_id: "foo",
        units: [unit]
      )

      insert(
        :node,
        external_id: "bar",
        units: [unit]
      )

      insert(
        :node,
        external_id: "baz",
        units: [unit]
      )

      conn = get(conn, Routes.node_path(conn, :index))
      assert resp = [%{"parent" => nil}] = json_response(conn, 200)["data"]
      refute Map.has_key?(hd(resp), "groups")
    end
  end
end
