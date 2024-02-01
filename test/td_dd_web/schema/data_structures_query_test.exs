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
