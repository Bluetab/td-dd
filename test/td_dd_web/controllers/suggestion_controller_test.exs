defmodule TdDdWeb.SuggestionControllerTest do
  use TdDdWeb.ConnCase

  import Routes

  describe "search" do
    @tag authentication: [role: "user", permissions: ["view_data_structure"]]
    test "foo", %{conn: conn} do
      conn
      |> post(suggestion_path(conn, :search), %{})
      |> response(:accepted)
    end
  end
end
