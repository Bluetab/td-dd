defmodule TdDq.CSV.ReaderTest do
  use TdDd.DataCase
  alias TdDq.CSV.Reader

  setup context do
    if path = context[:fixture] do
      stream = File.stream!("test/fixtures/implementations/" <> path)
      [stream: stream]
    else
      :ok
    end
  end

  describe "CSV.Reader" do
    @tag fixture: "implementations.csv"
    test "read_csv/2 return ok with records", %{stream: stream} do
      assert {:ok, _ids} = Reader.read_csv(stream)
    end
  end
end
