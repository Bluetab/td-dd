defmodule Truedat.Search.IndexerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  require Logger

  alias Truedat.Search.Indexer

  describe "log_bulk_post" do
    setup do
      errored_item_1 = %{
        "index" => %{
          "_id" => "1769343",
          "_index" => "structures-1691648696299822",
          "_type" => "_doc",
          "error" => %{
            "caused_by" => %{
              "caused_by" => %{
                "reason" => "Failed to parse with all enclosed parsers",
                "type" => "date_time_parse_exception"
              },
              "reason" =>
                "failed to parse date field [2022-11-28 09:32:55.036000000] with format [strict_date_optional_time||epoch_millis]",
              "type" => "illegal_argument_exception"
            },
            "reason" =>
              "failed to parse field [metadata.createdAt] of type [date] in document with id '1769343'. Preview of field's value: '2022-11-28 09:32:55.036000000'",
            "type" => "mapper_parsing_exception"
          },
          "status" => 400
        }
      }

      errored_item_2 = %{
        "index" => %{
          "_id" => "1769350",
          "_index" => "structures-1691648696299822",
          "_type" => "_doc",
          "error" => %{
            "caused_by" => %{
              "caused_by" => %{
                "reason" => "Failed to parse with all enclosed parsers",
                "type" => "date_time_parse_exception"
              },
              "reason" =>
                "failed to parse date field [2022-11-25 12:48:05.233999872] with format [strict_date_optional_time||epoch_millis]",
              "type" => "illegal_argument_exception"
            },
            "reason" =>
              "failed to parse field [metadata.createdAt] of type [date] in document with id '1769350'. Preview of field's value: '2022-11-25 12:48:05.233999872'",
            "type" => "mapper_parsing_exception"
          },
          "status" => 400
        }
      }

      successful_item = %{
        "index" => %{
          "_id" => "1769351",
          "_index" => "structures-1691648696299822",
          "_primary_term" => 1,
          "_seq_no" => 26_637,
          "_shards" => %{"failed" => 0, "successful" => 1, "total" => 2},
          "_type" => "_doc",
          "_version" => 19,
          "result" => "updated",
          "status" => 200
        }
      }

      [
        errored_item_1: errored_item_1,
        errored_item_2: errored_item_2,
        successful_item: successful_item
      ]
    end

    test "two errors", %{
      errored_item_1: errored_item_1,
      errored_item_2: errored_item_2,
      successful_item: successful_item
    } do
      post_bulk_response_items = [errored_item_1, errored_item_2, successful_item]

      log =
        capture_log(fn ->
          Indexer.log_bulk_post(
            "structures",
            {:ok, %{"errors" => true, "items" => post_bulk_response_items}},
            "index"
          )
        end)

      assert log =~ "structures"
      assert log =~ "bulk indexing encountered 2 errors"
      assert log =~ "Document ID 1769350"
      assert log =~ "Document ID 1769343"
      assert log =~ "failed to parse field"
      assert log =~ "2022-11-25 12:48:05.233999872"
      assert log =~ "2022-11-28 09:32:55.036000000"
    end
  end

  describe "log_hot_swap" do
    setup do
      elasticsearch_exception_1 = %Elasticsearch.Exception{
        status: 400,
        line: nil,
        col: nil,
        message:
          "failed to parse field [metadata.createdAt] of type [date] in document with id '1769350'. Preview of field's value: '2022-11-25 12:48:05.233999872'",
        type: "mapper_parsing_exception",
        query: nil,
        raw: %{
          "_id" => "1769350",
          "_index" => "structures-1691599336795214",
          "_type" => "_doc",
          "error" => %{
            "caused_by" => %{
              "caused_by" => %{
                "reason" => "Failed to parse with all enclosed parsers",
                "type" => "date_time_parse_exception"
              },
              "reason" =>
                "failed to parse date field [2022-11-25 12:48:05.233999872] with format [strict_date_optional_time||epoch_millis]",
              "type" => "illegal_argument_exception"
            },
            "reason" =>
              "failed to parse field [metadata.createdAt] of type [date] in document with id '1769350'. Preview of field's value: '2022-11-25 12:48:05.233999872'",
            "type" => "mapper_parsing_exception"
          },
          "status" => 400
        }
      }

      elasticsearch_exception_2 = %Elasticsearch.Exception{
        status: 400,
        line: nil,
        col: nil,
        message:
          "failed to parse field [metadata.createdAt] of type [date] in document with id '1769343'. Preview of field's value: '2022-11-28 09:32:55.036000000'",
        type: "mapper_parsing_exception",
        query: nil,
        raw: %{
          "_id" => "1769343",
          "_index" => "structures-1691599336795214",
          "_type" => "_doc",
          "error" => %{
            "caused_by" => %{
              "caused_by" => %{
                "reason" => "Failed to parse with all enclosed parsers",
                "type" => "date_time_parse_exception"
              },
              "reason" =>
                "failed to parse date field [2022-11-28 09:32:55.036000000] with format [strict_date_optional_time||epoch_millis]",
              "type" => "illegal_argument_exception"
            },
            "reason" =>
              "failed to parse field [metadata.createdAt] of type [date] in document with id '1769343'. Preview of field's value: '2022-11-28 09:32:55.036000000'",
            "type" => "mapper_parsing_exception"
          },
          "status" => 400
        }
      }

      elasticsearch_exception_3 = %Elasticsearch.Exception{
        status: 400,
        line: nil,
        col: nil,
        message:
          "Invalid alias name [structures]: an index or data stream exists with the same name as the alias",
        type: "invalid_alias_name_exception",
        query: nil,
        raw: %{
          "error" => %{
            "reason" =>
              "Invalid alias name [structures]: an index or data stream exists with the same name as the alias",
            "root_cause" => [
              %{
                "reason" =>
                  "Invalid alias name [structures]: an index or data stream exists with the same name as the alias",
                "type" => "invalid_alias_name_exception"
              }
            ],
            "type" => "invalid_alias_name_exception"
          },
          "status" => 400
        }
      }

      exception_connection_refused = %HTTPoison.Error{reason: :econnrefused, id: nil}
      exception_connection_closed = %HTTPoison.Error{reason: :closed, id: nil}

      [
        elasticsearch_exception_1: elasticsearch_exception_1,
        elasticsearch_exception_2: elasticsearch_exception_2,
        elasticsearch_exception_3: elasticsearch_exception_3,
        exception_connection_refused: exception_connection_refused,
        exception_connection_closed: exception_connection_closed
      ]
    end

    test "one exception, one element list", %{
      elasticsearch_exception_1: elasticsearch_exception_1
    } do
      log =
        capture_log(fn ->
          Indexer.log_hot_swap_errors(
            "structures-1691599336795214",
            {:error, [elasticsearch_exception_1]}
          )
        end)

      assert log =~ "build finished with an error"
      assert log =~ "structures-1691599336795214"
      assert log =~ "Document ID 1769350"
      assert log =~ "mapper_parsing_exception"
      assert log =~ "2022-11-25 12:48:05.233999872"
    end

    test "two exceptions", %{
      elasticsearch_exception_1: elasticsearch_exception_1,
      elasticsearch_exception_2: elasticsearch_exception_2
    } do
      log =
        capture_log(fn ->
          Indexer.log_hot_swap_errors(
            "structures-1691599336795214",
            {:error, [elasticsearch_exception_1, elasticsearch_exception_2]}
          )
        end)

      assert log =~ "build finished with 2 errors"
      assert log =~ "structures-1691599336795214"
      assert log =~ "Document ID 1769350"
      assert log =~ "Document ID 1769343"
      assert log =~ "mapper_parsing_exception"
      assert log =~ "2022-11-25 12:48:05.233999872"
      assert log =~ "2022-11-28 09:32:55.036000000"
    end

    test "one exception without containing list (index with same name already exists)", %{
      elasticsearch_exception_3: elasticsearch_exception_3
    } do
      log =
        capture_log(fn ->
          Indexer.log_hot_swap_errors(
            "structures-1691599336795214",
            {:error, elasticsearch_exception_3}
          )
        end)

      assert log =~ "structures-1691599336795214"
      assert log =~ "build finished with an error"
      assert log =~ "an index or data stream exists with the same name as the alias"
    end

    test "one exception without containing list (connection refused before starting hot_swap)", %{
      exception_connection_refused: exception_connection_refused
    } do
      log =
        capture_log(fn ->
          Indexer.log_hot_swap_errors(
            "structures-1691599336795214",
            {:error, exception_connection_refused}
          )
        end)

      assert log =~ "structures-1691599336795214"
      assert log =~ "build finished with an error"
      assert log =~ ":econnrefused"
    end

    test "multiple exceptions (connection refused and closed in the middle of hot_swap)", %{
      exception_connection_refused: exception_connection_refused,
      exception_connection_closed: exception_connection_closed
    } do
      log =
        capture_log(fn ->
          Indexer.log_hot_swap_errors(
            "structures-1691599336795214",
            {
              :error,
              [
                exception_connection_refused,
                exception_connection_refused,
                exception_connection_closed
              ]
            }
          )
        end)

      assert log =~ "structures-1691599336795214"
      assert log =~ "build finished with 3 errors"
      assert log =~ ":econnrefused"
    end
  end
end
