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

  describe "dataStructure query" do
    # setup [:put_domain, :put_permissions]

    @tag authentication: [role: "user"]
    test "returns forbidden if user has no permissions", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @structure_query, "variables" => %{"id" => 1}})
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
  end
end
