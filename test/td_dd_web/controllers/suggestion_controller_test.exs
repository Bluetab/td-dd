defmodule TdDdWeb.SuggestionControllerTest do
  use TdDdWeb.ConnCase

  import Routes

  alias TdCluster.TestHelpers.TdAiMock
  alias TdCluster.TestHelpers.TdBgMock

  describe "search" do
    @tag authentication: [
           role: "user",
           permissions: ["view_data_structure"]
         ]
    test "knn search for concept resource with default attrs", %{conn: conn, domain: domain} do
      id = 1
      version = 1

      resource = %{
        "type" => "concepts",
        "id" => id,
        "version" => version,
        "links" => [
          %{
            "resource_id" => "1",
            "name" => "name",
            "external_id" => "external_id",
            "type" => "type",
            "path" => ["1", "2"],
            "description" => "description"
          }
        ]
      }

      TdAiMock.Indices.exists_enabled?(&Mox.expect/4, {:ok, true})

      TdBgMock.generate_vector(
        &Mox.expect/4,
        %{
          id: 1,
          version: 1
        },
        nil,
        {:ok, {"default_collection_name", [54.0, 10.2, -2.0]}}
      )

      Mox.expect(ElasticsearchMock, :request, fn
        _, :post, "/structures/_search", %{knn: knn}, _ ->
          assert knn == %{
                   "field" => "embeddings.vector_default_collection_name",
                   "filter" => %{
                     bool: %{
                       "filter" => [
                         %{term: %{"domain_ids" => domain.id}},
                         %{term: %{"confidential" => false}}
                       ],
                       "must_not" => [%{term: %{"data_structure_id" => "1"}}]
                     }
                   },
                   "k" => 10,
                   "num_candidates" => 100,
                   "query_vector" => [54.0, 10.2, -2.0],
                   "similarity" => 0.60
                 }

          SearchHelpers.hits_response([])
      end)

      assert %{"data" => []} =
               conn
               |> post(suggestion_path(conn, :search), %{"resource" => resource})
               |> json_response(:ok)
    end
  end
end
