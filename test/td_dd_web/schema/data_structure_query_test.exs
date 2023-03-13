defmodule TdDdWeb.Schema.DataStructureQueryTest do
  use TdDdWeb.ConnCase

  alias TdDd.DataStructures.Hierarchy

  @structure_query """
  query DataStructure($id: ID!) {
    dataStructure(id: $id) {
      id
      availableTags {
        id
        name
      }
      structureTags {
        id
        comment
        inherit
        inherited
        tag {
          id
          name
        }
      }
    }
  }
  """

  @structure_structure_links_query """
  query DataStructureLinks($id: ID!) {
    dataStructure(id: $id) {
      id
      dataStructureLinks {
        _actions
        labels {
          name
        }
        source {
          id
          currentVersion {
            name
          }
          system {
            id
            name
          }
        }
        target {
          id
          currentVersion {
            name
          }
          system {
            id
            name
          }
        }
      }
      currentVersion {
        id
        name
      }
    }
  }
  """

  describe "dataStructure query" do
    # setup [:put_domain, :put_permissions]

    @tag authentication: [role: "user"]
    test "returns forbidden if user has no permissions", %{conn: conn} do
      %{id: id} = insert(:data_structure)

      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @structure_query, "variables" => %{"id" => id}})
               |> json_response(:ok)

      assert data == %{"dataStructure" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: [:view_data_structure]]
    test "returns not found when queried by permitted user", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @structure_query, "variables" => %{"id" => 1}})
               |> json_response(:ok)

      assert data == %{"dataStructure" => nil}
      assert [%{"message" => "not_found"}] = errors
    end

    @tag authentication: [
           role: "user",
           permissions: [:view_data_structure, :link_data_structure_tag]
         ]
    test "returns structure with tags and availableTags when queried by permitted user", %{
      conn: conn,
      domain: domain
    } do
      %{id: tag_id, name: tag_name} = insert(:tag, domain_ids: [domain.id, 123])

      %{data_structure_id: data_structure_id, id: data_structure_version_id} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, domain_ids: [domain.id])
        )

      %{id: structure_tag_id, comment: comment} =
        insert(:structure_tag, tag_id: tag_id, data_structure_id: data_structure_id)

      Hierarchy.update_hierarchy([data_structure_version_id])

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @structure_query,
                 "variables" => %{"id" => data_structure_id}
               })
               |> json_response(:ok)

      refute Map.has_key?(response, "errors")

      assert data == %{
               "dataStructure" => %{
                 "id" => "#{data_structure_id}",
                 "availableTags" => [%{"id" => "#{tag_id}", "name" => tag_name}],
                 "structureTags" => [
                   %{
                     "id" => "#{structure_tag_id}",
                     "comment" => comment,
                     "inherit" => false,
                     "inherited" => false,
                     "tag" => %{"id" => "#{tag_id}", "name" => tag_name}
                   }
                 ]
               }
             }
    end

    @tag authentication: [role: "user"]
    test "linked structures query returns forbidden if user has no permissions", %{conn: conn} do
      %{id: id} = insert(:data_structure)

      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @structure_structure_links_query,
                 "variables" => %{"id" => id}
               })
               |> json_response(:ok)

      assert data == %{"dataStructure" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [
           role: "user",
           permissions: [
             :view_data_structure,
             :link_data_structure_tag,
             :link_structure_to_structure
           ]
         ]
    test "returns structure with linked structures when queried by permitted user", %{
      conn: conn,
      domain: domain
    } do
      sys1 = insert(:system, external_id: "sys1", name: "sys1")
      sys2 = insert(:system, external_id: "sys2", name: "sys2")
      sys3 = insert(:system, external_id: "sys3", name: "sys3")

      domain2 = CacheHelpers.insert_domain()

      ds1 = insert(:data_structure, domain_ids: [domain.id], system_id: sys1.id)
      ds2 = insert(:data_structure, domain_ids: [domain.id], system_id: sys2.id)
      ds3 = insert(:data_structure, domain_ids: [domain2.id], system_id: sys3.id)

      %{data_structure_id: ds1_id, id: dsv1_id} =
        insert(:data_structure_version, data_structure: ds1, name: "dsv1")

      %{data_structure_id: _ds2_id, id: _dsv2_id} =
        insert(:data_structure_version, data_structure: ds2, name: "dsv2")

      %{data_structure_id: _ds3_id, id: _dsv3_id} =
        insert(:data_structure_version, data_structure: ds3, name: "dsv3")

      label1 = insert(:label, name: "label1")
      label2 = insert(:label, name: "label2")
      label3 = insert(:label, name: "label3")

      insert(:data_structure_link, source: ds1, target: ds2, labels: [label1, label2])
      insert(:data_structure_link, source: ds3, target: ds1, labels: [label3])

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @structure_structure_links_query,
                 "variables" => %{"id" => ds1_id}
               })
               |> json_response(:ok)

      refute Map.has_key?(response, "errors")

      assert data == %{
               "dataStructure" => %{
                 "currentVersion" => %{"id" => "#{dsv1_id}", "name" => "dsv1"},
                 "dataStructureLinks" => [
                   %{
                     "labels" => [%{"name" => "label1"}, %{"name" => "label2"}],
                     "source" => %{
                       "currentVersion" => %{"name" => "dsv1"},
                       "id" => "#{ds1.id}",
                       "system" => %{"id" => "#{sys1.id}", "name" => "sys1"}
                     },
                     "target" => %{
                       "currentVersion" => %{"name" => "dsv2"},
                       "id" => "#{ds2.id}",
                       "system" => %{"id" => "#{sys2.id}", "name" => "sys2"}
                     },
                     "_actions" => %{"delete_struct_to_struct_link" => true}
                   },
                   %{
                     "labels" => [%{"name" => "label3"}],
                     "source" => %{
                       "currentVersion" => %{"name" => "dsv3"},
                       "id" => "#{ds3.id}",
                       "system" => %{"id" => "#{sys3.id}", "name" => "sys3"}
                     },
                     "target" => %{
                       "currentVersion" => %{"name" => "dsv1"},
                       "id" => "#{ds1.id}",
                       "system" => %{"id" => "#{sys1.id}", "name" => "sys1"}
                     },
                     "_actions" => %{"delete_struct_to_struct_link" => false}
                   }
                 ],
                 "id" => "#{ds1_id}"
               }
             }
    end
  end
end
