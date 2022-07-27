defmodule TdDdWeb.Schema.DomainTest do
  use TdDdWeb.ConnCase

  @domains """
  query Domains($action: String!) {
    domains(action: $action) {
      id
      parentId
      externalId
      name
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
  end

  defp expected(%{} = d) do
    d
    |> Map.put_new(:parent_id, nil)
    |> Map.take([:id, :parent_id, :external_id, :name])
    |> Map.new(fn
      {k, nil} -> {Inflex.camelize(k, :lower), nil}
      {k, v} -> {Inflex.camelize(k, :lower), to_string(v)}
    end)
  end
end
