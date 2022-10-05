defmodule TdDq.Functions.BulkTest do
  use TdDd.DataCase

  alias TdDq.Functions.Bulk

  describe "Bulk.changeset/1" do
    test "validates embedded parameters" do
      params = %{"functions" => [%{"foo" => "bar"}]}
      assert %{valid?: false} = Bulk.changeset(params)

      params = %{"functions" => [string_params_for(:function)]}

      assert %{valid?: true} = Bulk.changeset(params)
    end
  end
end
