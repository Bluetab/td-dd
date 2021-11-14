defmodule TdDqWeb.ImplementationSearchControllerTest do
  use TdDqWeb.ConnCase

  alias TdCache.ConceptCache
  alias TdCache.TaxonomyCache

  @business_concept_id "42"

  setup_all do
    %{id: domain_id} = domain = build(:domain)
    TaxonomyCache.put_domain(domain)
    ConceptCache.put(%{id: @business_concept_id, name: "Concept", domain_id: domain_id})

    on_exit(fn ->
      {:ok, _} = ConceptCache.delete(@business_concept_id)
      TaxonomyCache.delete_domain(domain_id)
    end)

    [domain: domain]
  end

  setup tags do
    domain_id = get_in(tags, [:domain, :id])
    rule = insert(:rule, business_concept_id: @business_concept_id, domain_id: domain_id)
    implementation = insert(:implementation, rule: rule)
    [implementation: implementation, rule: rule]
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
      claims: %{user_id: user_id},
      domain: %{id: domain_id}
    } do
      assert %{"data" => [], "user_permissions" => perms} =
               conn
               |> post(Routes.implementation_search_path(conn, :create))
               |> json_response(:ok)

      assert %{"execute" => false, "manage" => false} = perms

      create_acl_entry(user_id, "domain", domain_id, [
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
