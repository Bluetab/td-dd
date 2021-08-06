defmodule TdDdWeb.UnitDomainControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  @moduletag sandbox: :shared

  describe "Unit Domain Controller" do
    @tag authentication: [role: "admin"]
    test "GET /api/units returns the list of units", %{conn: conn, swagger_schema: schema} do
      %{id: parent_domain_id} = CacheHelpers.insert_domain()
      %{id: domain_id} = CacheHelpers.insert_domain(%{parent_ids: [parent_domain_id]})
      %{id: sibling_domain_id} = CacheHelpers.insert_domain(%{parent_ids: [parent_domain_id]})
      insert(:unit)
      %{id: unit_id} = insert(:unit, domain_id: domain_id)
      %{id: sibling_unit_id} = insert(:unit, domain_id: sibling_domain_id)

      assert %{"data" => [_, _, _] = unit_domains} =
               conn
               |> get(Routes.unit_domain_path(conn, :index))
               |> validate_resp_schema(schema, "UnitDomainsResponse")
               |> json_response(:ok)

      assert %{"unit" => ^unit_id, "parent_ids" => parent_ids} =
               Enum.find(unit_domains, &(&1["id"] == domain_id))

      assert parent_ids == [parent_domain_id]

      assert %{"unit" => ^sibling_unit_id, "parent_ids" => parent_ids} =
               Enum.find(unit_domains, &(&1["id"] == sibling_domain_id))

      assert parent_ids == [parent_domain_id]
      assert %{"parent_ids" => []} = Enum.find(unit_domains, &(&1["id"] == parent_domain_id))
    end

    @tag authentication: [user_name: "foo", permissions: [:view_lineage]]
    test "GET /api/units returns the list of units with permissions over action", %{
      conn: conn,
      swagger_schema: schema,
      domain: %{id: domain_id}
    } do
      %{id: unit_id} = insert(:unit, domain_id: domain_id)

      assert %{"data" => [domain]} =
               conn
               |> get(Routes.unit_domain_path(conn, :index, actions: "view_lineage"))
               |> validate_resp_schema(schema, "UnitDomainsResponse")
               |> json_response(:ok)

      assert %{"unit" => ^unit_id, "parent_ids" => [], "id" => ^domain_id} = domain
    end
  end
end
