defmodule TdDqWeb.SearchControllerTest do
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
      claims: %{user_id: user_id},
      domain: %{id: domain_id}
    } do
      assert %{"data" => []} =
               conn
               |> post(Routes.search_path(conn, :search_rules))
               |> json_response(:ok)

      create_acl_entry(user_id, "domain", domain_id, [:view_quality_rule])

      assert %{"data" => [_]} =
               conn
               |> post(Routes.search_path(conn, :search_rules))
               |> json_response(:ok)
    end
  end
end
