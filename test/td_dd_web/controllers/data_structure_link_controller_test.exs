defmodule TdDdWeb.DataStructureLinkControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  describe "index" do
    setup do
      ds1 = insert(:data_structure, external_id: "ds1_external_id")
      ds2 = insert(:data_structure, external_id: "ds2_external_id")
      ds3 = insert(:data_structure, external_id: "ds3_external_id")

      label1 = insert(:label, name: "label1")
      label2 = insert(:label, name: "label2")
      label3 = insert(:label, name: "label3")

      insert(:data_structure_link, source: ds1, target: ds2, labels: [label1, label2])
      insert(:data_structure_link, source: ds3, target: ds1, labels: [label3])

      %{ds1: ds1, ds2: ds2, ds3: ds3, label1: label1, label2: label2, label3: label3}
    end

    @tag authentication: [role: "user"]
    test "index_by_external_id permission", %{
      conn: conn,
      ds1: %{external_id: ds1_external_id}
    } do
      conn
      |> get(
        "/api/data_structure_links/search_all",
        %{
          "external_id" => ds1_external_id
        }
      )
      |> json_response(:forbidden)
    end

    @tag authentication: [role: "service"]
    test "index_by_external_id index by structure external ID", %{
      conn: conn,
      ds1: %{external_id: ds1_external_id},
      ds2: %{external_id: ds2_external_id},
      ds3: %{external_id: ds3_external_id},
      label1: %{name: label1_name},
      label2: %{name: label2_name},
      label3: %{name: label3_name}
    } do
      assert %{"data" => data} =
               conn
               |> get(
                 "/api/data_structure_links/search_all",
                 %{
                   "external_id" => ds1_external_id
                 }
               )
               |> json_response(:ok)

      assert [
               %{
                 "labels" => [^label1_name, ^label2_name],
                 "source" => %{"external_id" => ^ds1_external_id},
                 "target" => %{"external_id" => ^ds2_external_id}
               },
               %{
                 "labels" => [^label3_name],
                 "source" => %{"external_id" => ^ds3_external_id},
                 "target" => %{"external_id" => ^ds1_external_id}
               }
             ] = data
    end

    @tag authentication: [role: "service"]
    test "index_by_id index by structure ID", %{
      conn: conn,
      ds1: %{id: ds1_id},
      ds2: %{id: ds2_id},
      ds3: %{id: ds3_id},
      label1: %{name: label1_name},
      label2: %{name: label2_name},
      label3: %{name: label3_name}
    } do
      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_data_structure_link_path(conn, :index, ds1_id))
               |> json_response(:ok)

      assert [
               %{
                 "labels" => [^label1_name, ^label2_name],
                 "source" => %{"id" => ^ds1_id},
                 "target" => %{"id" => ^ds2_id}
               },
               %{
                 "labels" => [^label3_name],
                 "source" => %{"id" => ^ds3_id},
                 "target" => %{"id" => ^ds1_id}
               }
             ] = data
    end
  end

  describe "search" do
    setup do
      ds1 = insert(:data_structure, external_id: "ds1_external_id")
      ds2 = insert(:data_structure, external_id: "ds2_external_id")
      label1 = insert(:label, name: "label1")
      label2 = insert(:label, name: "label2")
      insert(:data_structure_link, source: ds1, target: ds2, labels: [label1, label2])
      %{ds1: ds1, ds2: ds2, label1: label1, label2: label2}
    end

    @tag authentication: [role: "service"]
    test "search by source and target structure external IDs", %{
      conn: conn,
      ds1: %{external_id: ds1_external_id},
      ds2: %{external_id: ds2_external_id},
      label1: %{name: label1_name},
      label2: %{name: label2_name}
    } do
      assert %{"data" => data} =
               conn
               |> get(
                 "/api/data_structure_links/search_one",
                 %{
                   "source_external_id" => ds1_external_id,
                   "target_external_id" => ds2_external_id
                 }
               )
               |> json_response(:ok)

      assert %{
               "labels" => [^label1_name, ^label2_name],
               "source" => %{"external_id" => ^ds1_external_id},
               "target" => %{"external_id" => ^ds2_external_id}
             } = data
    end

    @tag authentication: [role: "service"]
    test "search by source and target structure IDs", %{
      conn: conn,
      ds1: %{id: ds1_id},
      ds2: %{id: ds2_id},
      label1: %{name: label1_name},
      label2: %{name: label2_name}
    } do
      assert %{"data" => data} =
               conn
               |> get("/api/data_structures/structure_links/source/#{ds1_id}/target/#{ds2_id}")
               |> json_response(:ok)

      assert %{
               "labels" => [^label1_name, ^label2_name],
               "source" => %{"id" => ^ds1_id},
               "target" => %{"id" => ^ds2_id}
             } = data
    end
  end

  describe "delete" do
    setup do
      ds1 = insert(:data_structure, external_id: "ds1_external_id")
      ds2 = insert(:data_structure, external_id: "ds2_external_id")
      label1 = insert(:label, name: "label1")
      label2 = insert(:label, name: "label2")
      insert(:data_structure_link, source: ds1, target: ds2, labels: [label1, label2])
      %{ds1: ds1, ds2: ds2, label1: label1, label2: label2}
    end

    @tag authentication: [role: "service"]
    test "delete by data structure IDs", %{
      conn: conn,
      ds1: %{id: ds1_id},
      ds2: %{id: ds2_id}
    } do
      assert conn
             |> delete("/api/data_structures/structure_links/source/#{ds1_id}/target/#{ds2_id}")
             |> response(:no_content)

      conn
      |> get("/api/data_structures/structure_links/source/#{ds1_id}/target/#{ds2_id}")
      |> json_response(:not_found)
    end

    @tag authentication: [role: "service"]
    test "delete by data structure external ids", %{
      conn: conn,
      ds1: %{external_id: ds1_external_id},
      ds2: %{external_id: ds2_external_id}
    } do
      assert conn
             |> delete(
               "/api/data_structure_links/search_delete_one",
               %{
                 "source_external_id" => ds1_external_id,
                 "target_external_id" => ds2_external_id
               }
             )
             |> response(:no_content)

      conn
      |> get(
        "/api/data_structure_links/search_one",
        %{
          "source_external_id" => ds1_external_id,
          "target_external_id" => ds2_external_id
        }
      )
      |> json_response(:not_found)
    end
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
