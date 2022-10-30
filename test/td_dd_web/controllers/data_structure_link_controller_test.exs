defmodule TdDdWeb.DataStructureLinkControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  @tag authentication: [role: "service"]
  test "show", %{conn: conn} do
    ds1 = insert(:data_structure, external_id: "ds1_external_id")
    ds2 = insert(:data_structure, external_id: "ds2_external_id")
    label1 = insert(:label, name: "label1")
    label2 = insert(:label, name: "label2")

    insert(:data_structure_link, source: ds1, target: ds2, labels: [label1, label2])

    assert %{"data" => data} =
             conn
             |> get(
               "/api/data_structure_links/search_one",
               %{
                 "source_external_id" => "ds1_external_id",
                 "target_external_id" => "ds2_external_id"
               }
             )
             |> json_response(:ok)

    assert %{
             "labels" => ["label1", "label2"],
             "source" => %{"external_id" => "ds1_external_id"},
             "target" => %{"external_id" => "ds2_external_id"}
           } = data
  end

  @tag authentication: [role: "service"]
  test "delete", %{conn: conn} do
    ds1 = insert(:data_structure, external_id: "ds1_external_id")
    ds2 = insert(:data_structure, external_id: "ds2_external_id")
    label1 = insert(:label, name: "label1")
    label2 = insert(:label, name: "label2")

    insert(:data_structure_link, source: ds1, target: ds2, labels: [label1, label2])

    assert conn
           |> delete(
             "/api/data_structure_links/search_delete_one",
             %{
               "source_external_id" => "ds1_external_id",
               "target_external_id" => "ds2_external_id"
             }
           )
           |> response(:no_content)

    conn
    |> get(
      "/api/data_structure_links/search_one",
      %{
        "source_external_id" => "ds1_external_id",
        "target_external_id" => "ds2_external_id"
      }
    )
    |> json_response(:not_found)
  end

  @tag authentication: [role: "service"]
  test "create: bulk load", %{conn: conn, swagger_schema: schema} do
    insert(:data_structure, external_id: "ds1_external_id")
    insert(:data_structure, external_id: "ds2_external_id")
    insert(:data_structure, external_id: "ds3_external_id")
    insert(:data_structure, external_id: "ds4_external_id")

    insert(:label, name: "label1")
    insert(:label, name: "label2")
    insert(:label, name: "label3")

    links = [
      %{
        "source_external_id" => "ds1_external_id",
        "target_external_id" => "ds2_external_id",
        "label_names" => ["label1"]
      },
      %{
        "source_external_id" => "ds3_external_id",
        "target_external_id" => "ds4_external_id",
        "label_names" => ["label2", "label3", "inexistent_label"]
      },
      %{
        "source_external_id" => "ds1_external_id",
        "target_external_id" => "inexistent_ds_external_id",
        "label_names" => ["label1"]
      },
      %{
        "source_external_id" => 1234,
        "target_external_id" => "ds2_external_id",
        "label_names" => ["label1"]
      }
    ]

    assert %{"data" => data} =
             conn
             |> post(
               Routes.data_structure_link_path(conn, :create),
               %{"data_structure_links" => links}
             )
             |> validate_resp_schema(schema, "BulkCreateDataStructureLinksResponse")
             |> json_response(:created)

    assert data == %{
             "inserted" => [
               %{
                 "source_external_id" => "ds1_external_id",
                 "target_external_id" => "ds2_external_id"
               },
               %{
                 "source_external_id" => "ds3_external_id",
                 "target_external_id" => "ds4_external_id"
               }
             ],
             "not_inserted" => %{
               "changeset_invalid_links" => [
                 [
                   %{
                     "field" => "source_external_id",
                     "message" => "is invalid",
                     "value" => 1234
                   }
                 ]
               ],
               "inexistent_structure" => [
                 %{
                   "source_external_id" => "ds1_external_id",
                   "target_external_id" => "inexistent_ds_external_id"
                 }
               ]
             }
           }
  end
end
