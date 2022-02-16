defmodule TdDqWeb.ImplementationSearchControllerTest do
  use TdDqWeb.ConnCase

  @business_concept_id "42"

  setup do
    %{id: domain_id} = domain = CacheHelpers.insert_domain()
    %{id: concept_id} = CacheHelpers.insert_concept(%{domain_id: domain_id})
    rule = insert(:rule, business_concept_id: concept_id, domain_id: domain_id)
    implementation = insert(:implementation, rule: rule, domain_id: domain_id)
    [domain: domain, implementation: implementation, rule: rule]
  end

  describe "POST /api/rule_implementations/search" do
    @tag authentication: [role: "admin"]
    test "admin can search implementations", %{conn: conn} do
      assert %{"data" => [_]} =
               conn
               |> post(Routes.implementation_search_path(conn, :create))
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "user with permissions can search implementations", %{
      conn: conn,
      claims: claims,
      domain: %{id: domain_id}
    } do
      assert %{"data" => [], "user_permissions" => perms} =
               conn
               |> post(Routes.implementation_search_path(conn, :create))
               |> json_response(:ok)

      assert %{"execute" => false, "manage" => false} = perms

      CacheHelpers.put_session_permissions(claims, domain_id, [
        :view_quality_rule,
        :manage_quality_rule_implementations,
        :execute_quality_rule_implementations
      ])

      assert %{"data" => [_], "user_permissions" => perms} =
               conn
               |> post(Routes.implementation_search_path(conn, :create))
               |> json_response(:ok)

      assert %{"execute" => true, "manage" => true} = perms
    end
  end

  describe "search with scroll" do
    @tag authentication: [role: "admin"]
    test "return scroll_id and pages results", %{conn: conn, domain: %{id: domain_id}} do
      rule = insert(:rule, business_concept_id: @business_concept_id, domain_id: domain_id)
      Enum.each(1..7, fn _ -> insert(:implementation, rule: rule) end)

      assert %{"data" => data, "scroll_id" => scroll_id} =
               conn
               |> post(Routes.implementation_search_path(conn, :create), %{
                 "size" => 5,
                 "scroll" => "1m"
               })
               |> json_response(:ok)

      assert length(data) == 5

      assert %{"data" => data, "scroll_id" => scroll_id} =
               conn
               |> post(Routes.implementation_search_path(conn, :create), %{
                 "scroll_id" => scroll_id,
                 "scroll" => "1m",
                 "opts" => %{"index" => "implementations"}
               })
               |> json_response(:ok)

      assert length(data) == 3

      assert %{"data" => [], "scroll_id" => _} =
               conn
               |> post(Routes.implementation_search_path(conn, :create), %{
                 "scroll_id" => scroll_id,
                 "scroll" => "1m",
                 "opts" => %{"index" => "implementations"}
               })
               |> json_response(:ok)
    end
  end
end
