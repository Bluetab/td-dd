defmodule TdDq.Functions.FunctionTest do
  use TdDd.DataCase

  alias TdDq.Functions.Function

  describe "changeset/2" do
    test "validates args" do
      params = params_for(:function, args: [%{"foo" => "bar"}])

      assert %{valid?: true} = Function.changeset(params)
    end
  end
end
