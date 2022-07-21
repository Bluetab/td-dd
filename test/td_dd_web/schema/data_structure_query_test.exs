defmodule TdDdWeb.Schema.DataStructureQueryTest do
  use TdDdWeb.ConnCase

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
        tag {
          id
          name
        }
      }
    }
  }
  """

  describe "dataStructure query" do
    setup [:put_domain, :put_permissions]

    @tag authentication: [role: "user"]
    test "returns forbidden if user has no permissions", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @structure_query, "variables" => %{"id" => 1}})
               |> json_response(:ok)

      assert data == %{"dataStructure" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user"]
    @tag permissions: [:view_data_structure]
    test "returns not found when queried by permitted user", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @structure_query, "variables" => %{"id" => 1}})
               |> json_response(:ok)

      assert data == %{"dataStructure" => nil}
      assert [%{"message" => "not_found"}] = errors
    end

    @tag authentication: [role: "user"]
    @tag permissions: [:view_data_structure, :link_data_structure_tag]
    test "returns structure with tags and availableTags when queried by permitted user", %{
      conn: conn,
      domain: domain
    } do
      %{id: tag_id, name: tag_name} = insert(:tag, domain_ids: [domain.id, 123])
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain.id])

      %{id: structure_tag_id, comment: comment} =
        insert(:structure_tag, tag_id: tag_id, data_structure_id: data_structure_id)

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
                     "tag" => %{"id" => "#{tag_id}", "name" => tag_name}
                   }
                 ]
               }
             }
    end
  end

  defp put_domain(_context) do
    [domain: CacheHelpers.insert_domain()]
  end

  defp put_permissions(context) do
    case context do
      %{permissions: permissions, claims: claims, domain: %{id: domain_id}} ->
        CacheHelpers.put_session_permissions(claims, domain_id, permissions)

      _ ->
        :ok
    end

    :ok
  end
end
