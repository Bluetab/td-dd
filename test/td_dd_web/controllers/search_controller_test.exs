defmodule TdDdWeb.SearchControllerTest do
  use TdDdWeb.ConnCase

  alias TdCache.TaxonomyCache

  @moduletag sandbox: :shared

  setup_all do
    %{id: domain_id} = domain = build(:domain)
    TaxonomyCache.put_domain(domain)

    on_exit(fn ->
      TaxonomyCache.delete_domain(domain_id)
    end)

    [domain: domain]
  end

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    :ok
  end

  setup tags do
    case tags do
      %{claims: %{user_id: user_id, user_name: user_name}} ->
        user = CacheHelpers.insert_user(id: user_id, user_name: user_name)
        [user: user]
      _ ->
        :ok
    end
  end

  describe "search" do
    setup :create_grant

    @tag authentication: [role: "admin"]
    test "admin can search grants", %{conn: conn} do
      assert %{"data" => [_]} =
               conn
               |> post(Routes.search_path(conn, :search_grants))
               |> json_response(:ok)

    end

    @tag authentication: [user_name: "non_admin_user", permissions: [:view_grants]]
    test "user with permissions can search grants", %{conn: conn} do
      assert %{"data" => [_]} =
               conn
               |> post(Routes.search_path(conn, :search_grants))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "user without permissions cannot search grants", %{
      conn: conn
    } do
      assert %{"data" => []} =
               conn
               |> post(Routes.search_path(conn, :search_grants))
               |> json_response(:ok)
    end
  end

  describe "search_my_grants" do

    setup do
      %{id: other_user_id} = CacheHelpers.insert_user()
      [other_user_id: other_user_id]
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "user without permissions can only view owned grants", %{
      conn: conn,
      claims: claims,
      domain: domain,
      other_user_id: other_user_id
    } do
      %{user_id: user_id} = claims
      %{id: owned_grant_id} = create_grant(user_id, domain.id)
      _not_owned_grant = create_grant(other_user_id, domain.id)

      assert %{"data" => [%{"id" => ^owned_grant_id}]} =
        conn
        |> post(Routes.search_path(conn, :search_my_grants))
        |> json_response(:ok)
    end
  end

  defp create_grant(context) do
    grant =
      case context do
        %{domain: domain, user: user} ->
          create_grant(user.id, domain.id)
        _ ->
          insert(:grant)
      end

    [grant: grant]
  end

  defp create_grant(user_id, domain_id) do
    data_structure = insert(:data_structure, domain_id: domain_id)
    data_structure_version = insert(:data_structure_version, data_structure: data_structure)
    insert(:grant, data_structure_version: data_structure_version, data_structure: data_structure, user_id: user_id)
  end
end
