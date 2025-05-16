defmodule TdDd.Search.SuggestionsTest do
  use TdDdWeb.ConnCase

  alias TdCluster.TestHelpers.TdBgMock
  alias TdDd.DataStructures.Search.Suggestions

  @moduletag sandbox: :shared

  describe "knn/3" do
    setup do
      start_supervised!(TdDd.Search.StructureEnricher)
      :ok
    end

    @tag authentication: [role: "admin"]
    test "knn search with default params", %{claims: claims} do
      id = 1
      version = 1
      resource = %{"type" => "concepts", "id" => id, "version" => version}

      TdBgMock.generate_vector(
        &Mox.expect/4,
        %{id: 1, version: 1},
        nil,
        {:ok, {"default", [54.0, 10.2, -2.0]}}
      )

      Mox.expect(ElasticsearchMock, :request, fn
        _, :post, "/structures/_search", request, _ ->
          assert request == %{
                   sort: ["_score"],
                   _source: %{excludes: ["embeddings"]},
                   knn: %{
                     "field" => "embeddings.vector_default",
                     "filter" => %{bool: %{"filter" => %{match_all: %{}}}},
                     "k" => 10,
                     "num_candidates" => 100,
                     "query_vector" => [54.0, 10.2, -2.0],
                     "similarity" => 0.60
                   }
                 }

          SearchHelpers.hits_response([insert(:data_structure_version)])
      end)

      assert %{total: 1, results: [result]} =
               Suggestions.knn(claims, :view_data_structure, %{"resource" => resource})

      assert result.similarity == 1.0
    end

    @tag authentication: [role: "admin"]
    test "knn search excludes previous link structure ids from search", %{claims: claims} do
      id = 1
      version = 1
      links = [%{"resource_id" => "1"}]
      resource = %{"type" => "concepts", "id" => id, "version" => version, "links" => links}

      TdBgMock.generate_vector(
        &Mox.expect/4,
        %{id: 1, version: 1},
        nil,
        {:ok, {"default", [54.0, 10.2, -2.0]}}
      )

      Mox.expect(ElasticsearchMock, :request, fn
        _, :post, "/structures/_search", request, _ ->
          assert request == %{
                   sort: ["_score"],
                   _source: %{excludes: ["embeddings"]},
                   knn: %{
                     "field" => "embeddings.vector_default",
                     "filter" => %{
                       bool: %{
                         "filter" => %{match_all: %{}},
                         "must_not" => [%{term: %{"data_structure_id" => "1"}}]
                       }
                     },
                     "k" => 10,
                     "num_candidates" => 100,
                     "query_vector" => [54.0, 10.2, -2.0],
                     "similarity" => 0.60
                   }
                 }

          SearchHelpers.hits_response([insert(:data_structure_version)])
      end)

      assert %{total: 1, results: [result]} =
               Suggestions.knn(claims, :view_data_structure, %{"resource" => resource})

      assert result.similarity == 1.0
    end

    @tag authentication: [role: "admin"]
    test "knn search overrides default params", %{claims: claims} do
      id = 1
      version = 1

      params = %{
        "resource" => %{
          "id" => id,
          "version" => version,
          "type" => "concepts"
        },
        "num_candidates" => 500,
        "k" => 22,
        "collection_name" => "foo",
        "similarity" => 0.8
      }

      TdBgMock.generate_vector(
        &Mox.expect/4,
        %{id: 1, version: 1},
        "foo",
        {:ok, {"foo", [54.0, 10.2, -2.0]}}
      )

      Mox.expect(ElasticsearchMock, :request, fn
        _, :post, "/structures/_search", request, _ ->
          assert request == %{
                   sort: ["_score"],
                   _source: %{excludes: ["embeddings"]},
                   knn: %{
                     "field" => "embeddings.vector_foo",
                     "filter" => %{bool: %{"filter" => %{match_all: %{}}}},
                     "k" => 22,
                     "num_candidates" => 500,
                     "query_vector" => [54.0, 10.2, -2.0],
                     "similarity" => 0.8
                   }
                 }

          SearchHelpers.hits_response([insert(:data_structure_version)])
      end)

      assert %{total: 1, results: [result]} =
               Suggestions.knn(claims, :view_data_structure, params)

      assert result.similarity == 1.0
    end
  end
end
