defmodule TdDq.CSV.ImplementationsReaderTest do
  use TdDd.DataCase

  alias TdDd.Search.MockIndexWorker
  alias TdDq.CSV.ImplementationsReader

  setup_all do
    start_supervised(MockIndexWorker)
    :ok
  end

  setup context do
    claims = build(:claims)

    if path = context[:fixture] do
      stream = File.stream!("test/fixtures/implementations/" <> path, [:trim_bom])

      [stream: stream, claims: claims]
    else
      [claims: claims]
    end
  end

  describe "CSV.Reader" do
    @tag fixture: "implementations.csv"
    @tag authentication: [role: "admin"]
    test "read_csv/4 return ok with records", %{stream: stream, claims: claims} do
      CacheHelpers.insert_template(name: "bar_template")
      insert(:rule, name: "rule_foo")

      assert {:ok, %{ids: _ids, errors: []}} =
               ImplementationsReader.read_csv(claims, stream, false, "en")
    end

    @tag fixture: "implementations_malformed.csv"
    @tag authentication: [role: "admin"]
    test "read_csv/4 return errors with invalid csv", %{stream: stream, claims: claims} do
      assert {:error, error} = ImplementationsReader.read_csv(claims, stream, false, "en")

      assert error == %{
               error: :missing_required_columns,
               expected: "implementation_key, result_type, goal, minimum",
               found: "with_no_required_headers, foo, bar"
             }
    end
  end
end
