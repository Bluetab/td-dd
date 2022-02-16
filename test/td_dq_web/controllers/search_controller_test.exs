defmodule TdDqWeb.SearchControllerTest do
  use TdDqWeb.ConnCase

  setup do
    %{id: domain_id} = domain = CacheHelpers.insert_domain()
    %{id: concept_id} = CacheHelpers.insert_concept(name: "Concept", domain_id: domain_id)
    rule = insert(:rule, business_concept_id: concept_id, domain_id: domain_id)
    implementation = insert(:implementation, rule: rule)
    [domain: domain, implementation: implementation, rule: rule]
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "admin can search rules", %{conn: conn} do
      assert %{"data" => [_]} =
               conn
               |> post(Routes.search_path(conn, :search_rules))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user with permissions can search rules", %{
      conn: conn,
      claims: claims,
      domain: %{id: domain_id}
    } do
      assert %{"data" => []} =
               conn
               |> post(Routes.search_path(conn, :search_rules))
               |> json_response(:ok)

      CacheHelpers.put_session_permissions(claims, domain_id, [:view_quality_rule])

      assert %{"data" => [_]} =
               conn
               |> post(Routes.search_path(conn, :search_rules))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user with permissions to create rules has manage_quality_rules equals true", %{
      conn: conn,
      claims: claims,
      domain: %{id: domain_id}
    } do
      assert %{"data" => []} =
               conn
               |> post(Routes.search_path(conn, :search_rules))
               |> json_response(:ok)

      CacheHelpers.put_session_permissions(claims, domain_id, [:manage_quality_rule])

      assert %{"user_permissions" => %{"manage_quality_rules" => true}} =
               conn
               |> post(Routes.search_path(conn, :search_rules))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user without permissions to create rules has manage_quality_rules equals false", %{
      conn: conn
    } do
      assert %{"data" => []} =
               conn
               |> post(Routes.search_path(conn, :search_rules))
               |> json_response(:ok)

      assert %{"user_permissions" => %{"manage_quality_rules" => false}} =
               conn
               |> post(Routes.search_path(conn, :search_rules))
               |> json_response(:ok)
    end
  end
end
