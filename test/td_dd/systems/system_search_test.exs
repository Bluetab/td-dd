defmodule TdDD.Systems.SystemSearchTest do
  use TdDdWeb.ConnCase

  import Mox

  alias TdDd.Systems.SystemSearch

  setup :verify_on_exit!

  describe "get_systems_with_count/3" do
    @tag authentication: [role: "user", permissions: ["view_data_structure"]]
    test "returns structures_count aggregations", %{claims: claims} do
      %{id: id1} = insert(:system, name: "sys1")
      %{id: id2} = insert(:system, name: "sys2")
      insert(:system, name: "sys3")

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/structures/_search", %{aggs: aggs, query: query, size: 0}, _ ->
          assert aggs == %{
                   "system_id" => %{
                     terms: %{field: "system_id", size: 200},
                     aggs: %{"types" => %{terms: %{field: "type.raw", size: 50}}}
                   }
                 }

          assert %{
                   bool: %{
                     must: [
                       %{term: %{"confidential" => false}},
                       %{term: %{"domain_ids" => _}}
                     ]
                   }
                 } = query

          SearchHelpers.aggs_response(%{
            "system_id" => %{
              "buckets" => [
                %{
                  "key" => id1,
                  "doc_count" => 1234,
                  "types" => %{
                    "buckets" => [
                      %{"key" => "type1", "doc_count" => 123},
                      %{"key" => "type2", "doc_count" => 234}
                    ]
                  }
                },
                %{
                  "key" => id2,
                  "doc_count" => 2345,
                  "types" => %{
                    "buckets" => [
                      %{"key" => "type2", "doc_count" => 123},
                      %{"key" => "type3", "doc_count" => 234}
                    ]
                  }
                }
              ]
            }
          })
      end)

      assert [
               %{
                 df_content: nil,
                 external_id: _,
                 id: _,
                 name: "sys1",
                 structures_count: %{
                   count: 1234,
                   types: [%{count: 123, name: "type1"}, %{count: 234, name: "type2"}]
                 }
               },
               %{
                 df_content: nil,
                 external_id: _,
                 id: _,
                 name: "sys2",
                 structures_count: %{
                   count: 2345,
                   types: [%{count: 123, name: "type2"}, %{count: 234, name: "type3"}]
                 }
               },
               %{
                 df_content: nil,
                 external_id: _,
                 id: _,
                 name: "sys3",
                 structures_count: %{count: 0}
               }
             ] = SystemSearch.get_systems_with_count(claims, :view_data_structure, %{})
    end
  end
end
