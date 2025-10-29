defmodule TdDd.GrantRequests.ElasticDocumentTest do
  use TdDd.DataCase

  import Mox

  alias CacheHelpers
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdDd.Grants.GrantRequest

  setup :verify_on_exit!

  describe "ElasticDocument implementation for GrantRequest" do
    test "includes status_reason field in grant request" do
      grant_request = %GrantRequest{
        id: 123,
        status_reason: "connection timeout error"
      }

      assert grant_request.status_reason == "connection timeout error"
    end

    test "handles nil status_reason gracefully" do
      grant_request = %GrantRequest{
        id: 456,
        status_reason: nil
      }

      assert grant_request.status_reason == nil
    end

    @tag :mocked
    test "includes status_reason in mappings" do
      MockClusterHandler
      |> expect(:call, fn :ai, TdAi.Indices, :list_indices, [[enabled: true]] -> [] end)

      mappings = ElasticDocumentProtocol.mappings(%GrantRequest{})

      assert %{
               mappings: %{
                 properties: %{
                   status_reason: %{
                     type: "text",
                     fields: %{keyword: %{type: "keyword"}}
                   }
                 }
               }
             } = mappings

      assert get_in(mappings, [:mappings, :properties, :status_reason, :type]) == "text"

      assert get_in(mappings, [:mappings, :properties, :status_reason, :fields, :keyword, :type]) ==
               "keyword"
    end

    test "includes status_reason in aggregations" do
      aggregations = ElasticDocumentProtocol.aggregations(%GrantRequest{})

      assert Map.has_key?(aggregations, "status_reason")

      assert %{
               terms: %{
                 field: "status_reason.keyword",
                 size: _
               }
             } = aggregations["status_reason"]
    end

    test "aggregations include all expected fields" do
      aggregations = ElasticDocumentProtocol.aggregations(%GrantRequest{})

      expected_fields = [
        "approved_by",
        "user",
        "current_status",
        "status_reason",
        "taxonomy",
        "type"
      ]

      for field <- expected_fields do
        assert Map.has_key?(aggregations, field), "Missing aggregation for field: #{field}"
      end
    end
  end
end
