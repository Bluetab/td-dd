defmodule TdDdWeb.Schema.ReferenceDataTest do
  use TdDdWeb.ConnCase

  @datasets """
  query ReferenceDatasets {
    referenceDatasets {
      id
      headers
      name
      rowCount
    }
  }
  """

  @dataset """
  query ReferenceDataset($id: ID!) {
    referenceDataset(id: $id) {
      id
      headers
      name
      rowCount
      rows
    }
  }
  """

  describe "referenceDatasets query" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by a regular user", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @datasets})
               |> json_response(:ok)

      assert %{"referenceDatasets" => nil} = data
      assert [%{"message" => "forbidden", "path" => ["referenceDatasets"]}] = errors
    end

    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "returns data when queried by #{role} account", %{conn: conn} do
        %{name: name} = insert(:reference_dataset)

        assert %{"data" => data} =
                 resp =
                 conn
                 |> post("/api/v2", %{"query" => @datasets})
                 |> json_response(:ok)

        refute Map.has_key?(resp, "errors")
        assert %{"referenceDatasets" => [dataset]} = data
        assert %{"name" => ^name, "rowCount" => 2} = dataset
      end
    end
  end

  describe "referenceDataset query" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by a regular user", %{conn: conn} do
      variables = %{"id" => "123"}

      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @dataset, "variables" => variables})
               |> json_response(:ok)

      assert %{"referenceDataset" => nil} = data
      assert [%{"message" => "forbidden", "path" => ["referenceDataset"]}] = errors
    end

    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "returns data when queried by #{role} account", %{conn: conn} do
        %{id: id, name: name} = insert(:reference_dataset)

        variables = %{"id" => "#{id}"}

        assert %{"data" => data} =
                 resp =
                 conn
                 |> post("/api/v2", %{"query" => @dataset, "variables" => variables})
                 |> json_response(:ok)

        refute Map.has_key?(resp, "errors")
        assert %{"referenceDataset" => dataset} = data
        assert %{"name" => ^name, "rowCount" => 2, "rows" => [_, _]} = dataset
      end
    end
  end
end
