defmodule TdDdWeb.NodeControllerTest do
  use TdDdWeb.ConnCase
  use TdDd.GraphDataCase

  alias TdDd.Lineage.GraphData
  alias TdDd.Lineage.GraphData.State

  setup_all do
    start_supervised(GraphData)
    :ok
  end

  setup tags do
    case tags do
      %{contains: contains, depends: depends} ->
        create_nodes(contains, depends)

      _ ->
        []
    end
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
    @tag contains: %{"foo" => ["bar", "baz"], "xyz" => ["x", "y"]}
    @tag depends: [{"bar", "baz"}, {"x", "y"}]
    test "index returns the top-level groups and parent nil filtered by domain id", %{
      conn: conn,
      nodes: nodes
    } do
      %{id: parent_domain_id} = CacheHelpers.insert_domain()
      %{id: domain_id} = CacheHelpers.insert_domain(%{parent_id: parent_domain_id})

      insert(:unit,
        domain_id: domain_id,
        nodes: Enum.filter(nodes, &(&1.external_id in ["foo", "bar", "baz"]))
      )

      conn = get(conn, Routes.node_path(conn, :index, domain_id: parent_domain_id))
      assert [%{"parent" => nil, "groups" => [group]}] = json_response(conn, 200)["data"]
      assert %{"external_id" => "foo", "name" => "foo"} = group

      conn = get(conn, Routes.node_path(conn, :index, domain_id: domain_id))
      assert [%{"parent" => nil, "groups" => [group]}] = json_response(conn, 200)["data"]
      assert %{"external_id" => "foo", "name" => "foo"} = group

      conn = get(conn, Routes.node_path(conn, :index))
      assert [%{"parent" => nil, "groups" => groups}] = json_response(conn, 200)["data"]
      for %{"external_id" => external_id} <- groups, do: assert(external_id in ["foo", "xyz"])
    end

    @tag authentication: [user_name: "non_admin_user", permissions: [:view_lineage]]
    @tag contains: %{}
    @tag depends: []
    test "index returns the top-level groups and parent nil filtered by domain id depending on user permissions",
         %{
           conn: conn,
           domain: %{id: parent_domain_id}
         } do
      %{id: domain_id} = CacheHelpers.insert_domain(parent_id: parent_domain_id)

      [nodes: nodes] =
        create_nodes(
          %{"foo" => ["bar", "baz"], "xyz" => ["x", "y"]},
          [{"bar", "baz"}, {"x", "y"}],
          [domain_id]
        )

      insert(:unit,
        domain_id: domain_id,
        nodes: Enum.filter(nodes, &(&1.external_id in ["foo", "bar", "baz"]))
      )

      conn = get(conn, Routes.node_path(conn, :index, domain_id: parent_domain_id))
      assert [%{"parent" => nil, "groups" => [group]}] = json_response(conn, 200)["data"]
      assert %{"external_id" => "foo", "name" => "foo"} = group

      conn = get(conn, Routes.node_path(conn, :index, domain_id: domain_id))
      assert [%{"parent" => nil, "groups" => [group]}] = json_response(conn, 200)["data"]
      assert %{"external_id" => "foo", "name" => "foo"} = group

      %{id: domain_id} = CacheHelpers.insert_domain()

      insert(:unit,
        domain_id: domain_id,
        nodes: Enum.filter(nodes, &(&1.external_id in ["xyz", "x", "y"]))
      )

      conn = get(conn, Routes.node_path(conn, :index, domain_id: domain_id))
      assert [%{"parent" => nil}] = json_response(conn, 200)["data"]

      conn = get(conn, Routes.node_path(conn, :index))
      assert [%{"parent" => nil, "groups" => [group]}] = json_response(conn, 200)["data"]
      assert %{"external_id" => "foo", "name" => "foo"} = group
    end

    @tag authentication: [user_name: "non_admin_user", permissions: [:view_lineage]]
    @tag contains: %{}
    @tag depends: []
    test "index returns groups filtered by domain id in data_structures depending on user permissions ",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      %{id: not_permissions_domain_id} = CacheHelpers.insert_domain()

      contains = %{
        "foo" => ["bar", "baz"],
        "xyz" => ["x", "y"],
        "other" => ["other_x", "other_y"]
      }

      depends = [{"bar", "baz"}, {"x", "y"}, {"other_x", "other_y"}]

      groups =
        Enum.map(contains, fn {parent, _chidren} ->
          %{id: data_structure_id} =
            case parent do
              "other" ->
                insert(:data_structure,
                  external_id: parent,
                  domain_ids: [not_permissions_domain_id]
                )

              _ ->
                insert(:data_structure, external_id: parent, domain_ids: [domain_id])
            end

          insert(:node,
            external_id: parent,
            type: "Group",
            domain_ids: [domain_id],
            structure_id: data_structure_id
          )
        end)

      resources =
        depends
        |> Enum.flat_map(fn {from, to} -> [from, to] end)
        |> Enum.uniq()
        |> Enum.map(fn external_id ->
          %{id: data_structure_id} =
            insert(:data_structure, external_id: external_id, domain_ids: [domain_id])

          insert(:node,
            external_id: external_id,
            type: "Resource",
            domain_ids: [domain_id],
            structure_id: data_structure_id
          )
        end)

      nodes = groups ++ resources

      insert(:unit,
        domain_id: domain_id,
        nodes:
          Enum.filter(
            nodes,
            &(&1.external_id in ["foo", "bar", "baz", "other", "other_x", "other_y"])
          )
      )

      GraphData.state(state: setup_state(%{contains: contains, depends: depends}))

      assert %{"data" => data} =
               conn
               |> get(Routes.node_path(conn, :index, domain_id: domain_id))
               |> json_response(:ok)

      assert [%{"parent" => nil, "groups" => [group]}] = data
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
      claims: claims,
      nodes: nodes
    } do
      %{id: domain_id} = CacheHelpers.insert_domain()

      insert(:unit,
        domain_id: domain_id,
        nodes: Enum.filter(nodes, &(&1.external_id in ["foo", "bar", "baz"]))
      )

      %{id: domain_id} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, domain_id, [
        :view_data_structure,
        :view_lineage
      ])

      insert(:unit,
        domain_id: domain_id,
        nodes: Enum.filter(nodes, &(&1.external_id in ["xyz", "x", "y"]))
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
           claims: claims,
           nodes: nodes
         } do
      %{id: domain_id} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, domain_id, [])

      insert(:unit,
        domain_id: domain_id,
        nodes: Enum.filter(nodes, &(&1.external_id in ["foo", "bar", "baz"]))
      )

      assert %{"data" => data} =
               conn
               |> get(Routes.node_path(conn, :index))
               |> json_response(:ok)

      assert [%{"parent" => nil} = first] = data
      refute Map.has_key?(first, "groups")
    end

    defp create_nodes(contains, depends, domain_ids \\ []) do
      groups =
        Enum.map(contains, fn {parent, _chidren} ->
          %{id: data_structure_id} =
            insert(:data_structure, external_id: parent, domain_ids: domain_ids)

          insert(:node,
            external_id: parent,
            type: "Group",
            domain_ids: domain_ids,
            structure_id: data_structure_id
          )
        end)

      resources =
        depends
        |> Enum.flat_map(fn {from, to} -> [from, to] end)
        |> Enum.uniq()
        |> Enum.map(fn external_id ->
          %{id: data_structure_id} =
            insert(:data_structure, external_id: external_id, domain_ids: domain_ids)

          insert(:node,
            external_id: external_id,
            type: "Resource",
            domain_ids: domain_ids,
            structure_id: data_structure_id
          )
        end)

      GraphData.state(state: setup_state(%{contains: contains, depends: depends}))
      [nodes: groups ++ resources]
    end
  end
end
