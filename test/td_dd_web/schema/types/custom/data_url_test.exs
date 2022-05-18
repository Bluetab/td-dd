defmodule TdDdWeb.Schema.Types.Custom.DataURLTest do
  use ExUnit.Case

  alias Absinthe.Blueprint.Input.String
  alias TdDdWeb.Schema.Types.Custom.DataURL

  describe "DataURL.decode/1" do
    test "decodes a valid Data URL" do
      value = "data:text/csv;base64,Rk9PO0JBUjtCQVo="
      assert DataURL.decode(%String{value: value}) == {:ok, "FOO;BAR;BAZ"}
    end
  end
end
