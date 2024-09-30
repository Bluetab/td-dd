defmodule TdDdWeb.Schema.DataStructuresQueryTest do
  use TdDdWeb.ConnCase

  @structures_query """
  query LineageStructures($since: DateTime) {
    dataStructures(since: $since, lineage: true) {
      id
      externalId
      units {
        id
        name
      }
    }
  }
  """

  @structure_ids_query """
    query DataStructures($domain_ids: [Int]) {
    dataStructures(domain_ids: $domain_ids) {
      id
    }
  }
  """

  @external_id_query """
  query StructuresByExternalId($externalId: [String]) {
    dataStructures(externalId: $externalId) {
      id
      externalId
    }
  }
  """

  describe "dataStructures query" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @structures_query, "variables" => %{}})
               |> json_response(:ok)

      assert data == %{"dataStructures" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "service"]
    test "returns data when queried by service role", %{conn: conn} do
      %{data_structure: %{id: structure_id, external_id: external_id}} =
        insert(:data_structure_version)

      %{units: [%{name: unit_name}]} =
        insert(:node, structure_id: structure_id, units: [build(:unit)])

      variables = %{"since" => "2020-01-01T00:00:00Z"}

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @structures_query, "variables" => variables})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"dataStructures" => data_structures} = data
      assert [%{"id" => _, "externalId" => ^external_id, "units" => units}] = data_structures
      assert [%{"id" => _, "name" => ^unit_name}] = units
    end

    @tag authentication: [role: "agent"]
    test "returns data when queried by agent role", %{conn: conn, claims: claims} do
      %{id: domain_id} = CacheHelpers.insert_domain()
      %{id: domain_id2} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{
        "view_data_structure" => [domain_id, domain_id2]
      })

      %{data_structure_id: ds_id} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, domain_ids: [domain_id])
        )

      variables = %{"domain_ids" => [domain_id]}

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @structure_ids_query, "variables" => variables})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"dataStructures" => data_structures} = data
      string_ds_id = to_string(ds_id)
      assert [%{"id" => ^string_ds_id}] = data_structures
    end

    @tag authentication: [role: "agent"]
    test "returns forbidden when agent role not has domain permissions", %{
      conn: conn,
      claims: claims
    } do
      %{id: domain_id} = CacheHelpers.insert_domain()

      insert(:data_structure_version,
        data_structure: build(:data_structure, domain_ids: [domain_id])
      )

      variables = %{"domain_ids" => [domain_id]}

      assert response =
               conn
               |> post("/api/v2", %{"query" => @structure_ids_query, "variables" => variables})
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = response["errors"]

      assert response2 =
               conn
               |> post("/api/v2", %{"query" => @structure_ids_query})
               |> json_response(:ok)

      assert [%{"message" => "forbidden"}] = response2["errors"]
    end

    @tag authentication: [role: "service"]
    test "can filter by external_id when queried by service role", %{conn: conn} do
      insert(:data_structure_version)
      %{data_structure: %{external_id: external_id}} = insert(:data_structure_version)

      variables = %{"externalId" => [external_id, "foo"]}

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @external_id_query, "variables" => variables})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"dataStructures" => data_structures} = data
      assert [%{"id" => _, "externalId" => ^external_id}] = data_structures
    end
  end
end
