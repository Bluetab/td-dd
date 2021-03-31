defmodule TdDdWeb.ExecutionSearchControllerTest do
  use TdDdWeb.ConnCase

  setup do
    execution =
      insert(:execution,
        group: build(:execution_group),
        data_structure: build(:data_structure)
      )

    [execution: execution]
  end

  describe "POST /api/data_structures/executions/search" do
    @tag authentication: [role: "service"]
    test "service account can search executions", %{conn: conn} do
      params = %{"foo" => "bar"}

      assert %{"data" => [_]} =
               conn
               |> post(Routes.execution_search_path(conn, :create), params)
               |> json_response(:ok)
    end
  end
end
