defmodule TdDq.Search.HelpersTest do
  use TdDd.DataCase

  alias TdDq.Search.Helpers

  @moduletag sandbox: :shared

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    :ok
  end

  describe "get_sources/1" do
    test "extracts aliases from structure metadata" do
      ids =
        [%{}, %{"alias" => "foo"}, %{"alias" => "foo"}, %{"alias" => "bar"}]
        |> Enum.map(&insert(:data_structure_version, metadata: &1))
        |> Enum.map(& &1.data_structure_id)

      assert Helpers.get_sources(ids) == ["foo", "bar"]
    end
  end
end
