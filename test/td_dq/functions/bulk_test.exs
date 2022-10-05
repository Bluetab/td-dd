defmodule TdDq.Functions.BulkTest do
  use ExUnit.Case

  alias TdDq.Functions.Bulk

  describe "Bulk.changeset/1" do
    test "validates embedded parameters" do
      params = %{"functions" => [%{"foo" => "bar"}]}
      assert %{valid?: false} = Bulk.changeset(params)

      params = %{"functions" => [%{"name" => "foo", "args" => [%{"type" => "string"}]}]}
      assert %{valid?: true} = Bulk.changeset(params)
    end
  end
end
