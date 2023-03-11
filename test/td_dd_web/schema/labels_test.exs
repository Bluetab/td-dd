defmodule TdDdWeb.Schema.LabelsTest do
  use TdDdWeb.ConnCase

  @labels_query """
  query StructureToStructureLabels {
    labels {
      id
      name
    }
  }
  """

  defp create_labels(%{} = _context) do
    label1 = insert(:label, name: "label1")
    label2 = insert(:label, name: "label2")
    [labels: [label1, label2]]
  end

  describe "labels queries" do
    setup :create_labels

    @tag authentication: [role: "admin"]
    test "returns :ok when queried by admin", %{
      conn: conn
    } do
      assert %{"data" => _data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @labels_query})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @labels_query
               })
               |> json_response(:ok)

      assert data == %{"labels" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: [:link_structure_to_structure]]
    test "returns data when queried by user with permissions", %{
      conn: conn,
      labels: [label1, label2]
    } do
      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @labels_query})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert %{"labels" => queried_labels} = data

      assert [
               %{
                 "id" => queried_label1_id,
                 "name" => queried_label1_name
               },
               %{
                 "id" => queried_label2_id,
                 "name" => queried_label2_name
               }
             ] = queried_labels

      assert queried_label1_id == to_string(label1.id)
      assert queried_label2_id == to_string(label2.id)
      assert queried_label1_name == label1.name
      assert queried_label2_name == label2.name
    end
  end
end
