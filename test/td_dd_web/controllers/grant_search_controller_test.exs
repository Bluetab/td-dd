defmodule TdDdWeb.GrantSearchControllerTest do
  use TdDdWeb.ConnCase

  import Mox

  alias TdDd.DataStructures.Hierarchy

  @moduletag sandbox: :shared

  setup do
    start_supervised!(TdCore.Search.Cluster)
    start_supervised!(TdCore.Search.IndexWorker)

    :ok
  end

  setup :verify_on_exit!
  setup :create_grant

  describe "search" do
    @tag authentication: [role: "admin"]
    test "admin can search all grants without deleted_at", %{conn: conn, grant: grant} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/grants/_search", %{query: query, size: 20}, _ ->
        assert query == %{
                 bool: %{
                   must: %{match_all: %{}},
                   must_not: %{exists: %{field: "deleted_at"}}
                 }
               }

        SearchHelpers.hits_response([grant])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.grant_search_path(conn, :search_grants))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "non_admin_user", permissions: [:view_grants]]
    test "user with permissions filters by domain_id, user_id and deleted_at", %{
      conn: conn,
      grant: grant
    } do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/grants/_search", %{query: query, size: 20}, _ ->
        assert %{
                 bool: %{
                   must: %{
                     bool: %{
                       should: [
                         %{term: %{"data_structure_version.domain_ids" => _}},
                         %{term: %{"user_id" => _}}
                       ]
                     }
                   },
                   must_not: _deleted_at
                 }
               } = query

        SearchHelpers.hits_response([grant])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.grant_search_path(conn, :search_grants))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "user without permissions filters by user_id and deleted_at", %{conn: conn, grant: grant} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/grants/_search", %{query: query, size: 20}, _ ->
        assert %{
                 bool: %{
                   must: %{term: %{"user_id" => _}},
                   must_not: _deleted_at
                 }
               } = query

        SearchHelpers.hits_response([grant])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.grant_search_path(conn, :search_grants))
               |> json_response(:ok)
    end
  end

  describe "search_my_grants" do
    @tag authentication: [user_name: "non_admin_user", permissions: [:create_grant_request]]
    test "user without permissions filters by user_id and deleted_at", %{
      conn: conn,
      claims: %{user_id: user_id},
      grant: grant
    } do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/grants/_search", %{query: query, size: 20}, _ ->
        assert query == %{
                 bool: %{
                   must: %{term: %{"user_id" => user_id}},
                   must_not: %{exists: %{field: "deleted_at"}}
                 }
               }

        SearchHelpers.hits_response([grant])
      end)

      assert %{"data" => [_]} =
               conn
               |> post(Routes.grant_search_path(conn, :search_my_grants))
               |> json_response(:ok)
    end
  end

  describe "search grants by scroll" do
    @tag authentication: [role: "admin"]
    test "returns scroll_id and pages results", %{conn: conn} = context do
      grants = Enum.map(1..7, fn _ -> create_grant(context)[:grant] end)

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/grants/_search", %{query: query, size: 5}, [params: %{"scroll" => "1m"}] ->
          assert query == %{bool: %{must: %{match_all: %{}}}}
          SearchHelpers.scroll_response(Enum.take(grants, 5))
      end)
      |> expect(:request, fn
        _, :post, "/_search/scroll", body, [] ->
          assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
          SearchHelpers.scroll_response(Enum.drop(grants, 5))
      end)

      assert %{"data" => data, "scroll_id" => scroll_id} =
               conn
               |> post(Routes.grant_search_path(conn, :search_grants), %{
                 "size" => 5,
                 "scroll" => "1m",
                 "without" => []
               })
               |> json_response(:ok)

      assert length(data) == 5

      assert %{"data" => data, "scroll_id" => _} =
               conn
               |> post(Routes.grant_search_path(conn, :search_grants), %{
                 "scroll_id" => scroll_id,
                 "scroll" => "1m"
               })
               |> json_response(:ok)

      assert length(data) == 2
    end
  end

  defp create_grant(context) do
    user_id =
      case context do
        %{claims: %{user_id: user_id}} -> user_id
        _ -> System.unique_integer([:positive])
      end

    grant =
      case context do
        %{domain: domain} -> create_grant(user_id, [domain.id])
        _ -> create_grant(user_id, [])
      end

    [grant: grant]
  end

  defp create_grant(user_id, domain_ids) do
    data_structure = insert(:data_structure, domain_ids: domain_ids)
    data_structure_version = insert(:data_structure_version, data_structure: data_structure)
    Hierarchy.update_hierarchy([data_structure_version.id])

    insert(:grant,
      data_structure_version: data_structure_version,
      data_structure: data_structure,
      user_id: user_id
    )
  end
end
