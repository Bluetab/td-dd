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

  @create_dataset """
  mutation CreateReferenceDataset($dataset: CreateReferenceDatasetInput!) {
    createReferenceDataset(dataset: $dataset) {
      id
      headers
      name
      rowCount
      rows
    }
  }
  """

  @update_dataset """
  mutation UpdateReferenceDataset($dataset: UpdateReferenceDatasetInput!) {
    updateReferenceDataset(dataset: $dataset) {
      id
      headers
      name
      rowCount
      rows
    }
  }
  """

  @delete_dataset """
  mutation DeleteReferenceDataset($id: ID!) {
    deleteReferenceDataset(id: $id) {
      id
    }
  }
  """

  @data "data:text/csv;base64,Rk9PO0JBUjtCQVoKZm9vMTtiYXIxO2JhejE="

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

  describe "createReferenceDataset mutation" do
    for role <- ["user", "service"] do
      @tag authentication: [role: role]
      test "returns forbidden when sent by a #{role} account", %{conn: conn} do
        variables = %{"dataset" => %{"name" => "foo", "data" => @data}}

        assert %{"data" => data, "errors" => errors} =
                 conn
                 |> post("/api/v2", %{"query" => @create_dataset, "variables" => variables})
                 |> json_response(:ok)

        assert %{"createReferenceDataset" => nil} = data
        assert [%{"message" => "forbidden", "path" => ["createReferenceDataset"]}] = errors
      end
    end

    @tag authentication: [role: "admin"]
    test "creates dataset when sent by an admin user", %{conn: conn} do
      variables = %{"dataset" => %{"name" => "foo", "data" => @data}}

      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @create_dataset, "variables" => variables})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert %{"createReferenceDataset" => dataset} = data

      assert %{
               "headers" => [_, _, _],
               "id" => _,
               "name" => "foo",
               "rowCount" => 1,
               "rows" => [_]
             } = dataset
    end
  end

  describe "updateReferenceDataset mutation" do
    for role <- ["user", "service"] do
      @tag authentication: [role: role]
      test "returns forbidden when sent by a #{role} account", %{conn: conn} do
        variables = %{"dataset" => %{"id" => "123", "name" => "foo", "data" => @data}}

        assert %{"data" => data, "errors" => errors} =
                 conn
                 |> post("/api/v2", %{"query" => @update_dataset, "variables" => variables})
                 |> json_response(:ok)

        assert %{"updateReferenceDataset" => nil} = data
        assert [%{"message" => "forbidden", "path" => ["updateReferenceDataset"]}] = errors
      end
    end

    @tag authentication: [role: "admin"]
    test "updates dataset when sent by an admin user", %{conn: conn} do
      %{id: id} = insert(:reference_dataset)
      variables = %{"dataset" => %{"id" => "#{id}", "name" => "bar", "data" => @data}}

      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @update_dataset, "variables" => variables})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert %{"updateReferenceDataset" => dataset} = data

      assert %{
               "headers" => [_, _, _],
               "id" => _,
               "name" => "bar",
               "rowCount" => 1,
               "rows" => [_]
             } = dataset
    end
  end

  describe "deleteReferenceDataset mutation" do
    for role <- ["user", "service"] do
      @tag authentication: [role: role]
      test "returns forbidden when sent by a #{role} account", %{conn: conn} do
        variables = %{"id" => "123"}

        assert %{"data" => data, "errors" => errors} =
                 conn
                 |> post("/api/v2", %{"query" => @delete_dataset, "variables" => variables})
                 |> json_response(:ok)

        assert %{"deleteReferenceDataset" => nil} = data
        assert [%{"message" => "forbidden", "path" => ["deleteReferenceDataset"]}] = errors
      end
    end

    @tag authentication: [role: "admin"]
    test "deletes dataset when sent by an admin account", %{conn: conn} do
      %{id: id} = insert(:reference_dataset)
      variables = %{"id" => "#{id}"}

      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @delete_dataset, "variables" => variables})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert %{"deleteReferenceDataset" => ^variables} = data
    end
  end
end
