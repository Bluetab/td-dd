defmodule TdDq.FunctionsTest do
  use TdDd.DataCase

  alias TdDq.Functions

  describe "Functions.replace_all/1" do
    test "replaces all functions" do
      insert(:function)
      functions = Enum.map(1..10, fn _ -> params_for(:function) end)

      assert {:ok, %{delete_all: delete_all}} = Functions.replace_all(%{"functions" => functions})
      assert {1, nil} = delete_all

      assert {:ok, %{delete_all: delete_all}} = Functions.replace_all(%{"functions" => functions})
      assert {10, nil} = delete_all
    end
  end
end
