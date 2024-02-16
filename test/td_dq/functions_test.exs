defmodule TdDq.FunctionsTest do
  use TdDd.DataCase

  alias TdDq.Functions

  describe "Functions.get_function!/1" do
    test "returns a function" do
      %{id: id} = insert(:function)
      assert Functions.get_function!(id)
    end

    test "raises" do
      assert_raise Ecto.NoResultsError, fn ->
        Functions.get_function!(99)
      end
    end
  end

  describe "Functions.create_function/1" do
    test "returns a function" do
      params = string_params_for(:function)
      assert {:ok, _} = Functions.create_function(params)
    end
  end

  describe "Functions.delete_function/1" do
    test "deletes a function" do
      function = insert(:function)
      assert {:ok, _} = Functions.delete_function(function)
    end
  end

  describe "Functions.list_functions/0" do
    test "returns all functions" do
      for _ <- 1..10, do: insert(:function)

      [_ | _] = functions = Functions.list_functions()
      assert length(functions) == 10
    end
  end

  describe "Functions.replace_all/1" do
    test "replaces all functions" do
      functions = Enum.map(1..10, fn _ -> string_params_for(:function) end)

      assert {:ok, %{delete_all: delete_all}} = Functions.replace_all(%{"functions" => functions})
      assert {0, nil} = delete_all

      assert {:ok, %{delete_all: delete_all}} = Functions.replace_all(%{"functions" => functions})
      assert {10, nil} = delete_all
    end

    test "returns errors when params are invalid" do
      params = [%{"foo" => "bar"}, string_params_for(:function)]

      assert {:error, %{valid?: false} = changeset} =
               Functions.replace_all(%{"functions" => params})

      assert Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) == %{
               functions: [
                 %{
                   args: ["can't be blank"],
                   name: ["can't be blank"],
                   return_type: ["can't be blank"]
                 },
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
