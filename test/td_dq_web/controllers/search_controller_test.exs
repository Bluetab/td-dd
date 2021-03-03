defmodule TdDqWeb.SearchControllerTest do
  use TdDqWeb.ConnCase

  alias TdCache.TaxonomyCache

  @business_concept_id "42"

  setup_all do
    %{id: domain_id} = domain = build(:domain)
    TaxonomyCache.put_domain(domain)
    on_exit(fn -> TaxonomyCache.delete_domain(domain_id) end)

    [domain: domain]
  end

  setup do
    rule = insert(:rule, business_concept_id: @business_concept_id)
    implementation = insert(:implementation, rule: rule)
    [implementation: implementation, rule: rule]
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
    test "user with permissions can search rules", %{conn: conn, claims: %{user_id: user_id}} do
      assert %{"data" => []} =
               conn
               |> post(Routes.search_path(conn, :search_rules))
               |> json_response(:ok)

      create_acl_entry(user_id, "domain", 1, [:view_quality_rule])

      assert %{"data" => [_]} =
               conn
               |> post(Routes.search_path(conn, :search_rules))
               |> json_response(:ok)
    end
  end
end
