defmodule TdDq.FunctionsTest do
  use TdDd.DataCase

  alias TdDq.Functions

  describe "Functions.replace_all/1" do
    test "replaces all functions" do
      insert(:function)
      functions = Enum.map(1..10, fn _ -> string_params_for(:function) end)

      assert {:ok, %{delete_all: delete_all}} = Functions.replace_all(%{"functions" => functions})
      assert {1, nil} = delete_all

      assert {:ok, %{delete_all: delete_all}} = Functions.replace_all(%{"functions" => functions})
      assert {10, nil} = delete_all
    end

    test "returns errors when params are invalid" do
      params = [%{"foo" => "bar"}, string_params_for(:function)]

      assert {:error, %{valid?: false} = changeset} =
               Functions.replace_all(%{"functions" => params})

      assert Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) == %{
               functions: [
                 %{args: ["can't be blank"], name: ["can't be blank"]},
                 %{}
               ]
             }
    end

    test "returns errors when duplicates exist" do
      params = string_params_for(:function)

      assert {:error, 1, _changeset, %{0 => _}} =
               Functions.replace_all(%{"functions" => [params, params]})
    end
  end
end
