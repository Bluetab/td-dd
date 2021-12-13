defmodule TdDq.CSV.ReaderTest do
  use TdDd.DataCase

  alias TdDq.CSV.Reader
  alias TdDq.Implementations.MockBulkLoad

  @required_headers [
    "rule_name",
    "implementation_key",
    "result_type",
    "goal",
    "minimum",
    "template"
  ]

  setup_all do
    start_supervised(MockBulkLoad)
    :ok
  end

  setup context do
    claims = build(:dq_claims)

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
    test "read_csv/2 return ok with records", %{stream: stream, claims: claims} do
      assert {:ok, %{ids: _ids, errors: []}} =
               Reader.read_csv(claims, stream, @required_headers, &MockBulkLoad.bulk_load/2)
    end

    @tag fixture: "implementations_malformed.csv"
    @tag authentication: [role: "admin"]
    test "read_csv/2 return errors with incalid csv", %{stream: stream, claims: claims} do
      assert error = Reader.read_csv(claims, stream, @required_headers, &MockBulkLoad.bulk_load/2)

      assert {:error, %{error: :misssing_required_columns}} = error
    end
  end
end

defmodule TdDq.Implementations.MockBulkLoad do
  @moduledoc false

  use Agent

  def start_link(_) do
    Agent.start_link(fn -> [System.unique_integer([:positive])] end, name: __MODULE__)
  end

  def bulk_load(implementations, _claims) do
    last = Agent.get(__MODULE__, &List.last(&1))
    count = Enum.count(implementations)
    seq = Enum.map(Enum.to_list(1..count), fn sec -> last + sec end)
    Agent.update(__MODULE__, &List.flatten(&1, seq))
    {:ok, %{ids: seq, errors: []}}
  end
end
