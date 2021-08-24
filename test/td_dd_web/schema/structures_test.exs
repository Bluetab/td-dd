defmodule TdDdWeb.Schema.StructuresTest do
  use TdDdWeb.ConnCase

  @query """
  query DataStructureVersions($since: DateTime) {
    dataStructureVersions(since: $since) {
      id
      metadata
      dataStructure {
        id
        externalId
        system {
          id
          externalId
        }
      }
    }
  }
  """
  @variables %{"since" => "2020-01-01T00:00:00Z"}
  @metadata %{"foo" => ["bar"]}

  describe "dataStructureVersions query" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @query, "variables" => @variables})
               |> json_response(:ok)

      assert data == %{"dataStructureVersions" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "service"]
    test "returns data when queried by service role", %{conn: conn} do
      insert(:data_structure_version,
        updated_at: ~U[2019-01-01T00:00:00Z],
        deleted_at: ~U[2019-01-01T00:00:00Z]
      )

      %{id: expected_id} = insert(:data_structure_version, metadata: @metadata)

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @query, "variables" => @variables})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"dataStructureVersions" => data_structure_versions} = data
      assert [%{"id" => id, "dataStructure" => data_structure, "metadata" => @metadata}] = data_structure_versions
      assert id == to_string(expected_id)
      assert %{"id" => _, "externalId" => _, "system" => system} = data_structure
      assert %{"id" => _, "externalId" => _} = system
    end
  end
end
