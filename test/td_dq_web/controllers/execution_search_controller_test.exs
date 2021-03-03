defmodule TdDqWeb.ExecutionSearchControllerTest do
  use TdDqWeb.ConnCase

  setup do
    execution =
      insert(:execution,
        group: build(:execution_group),
        implementation: build(:implementation, rule: build(:rule))
      )

    [execution: execution]
  end

  describe "POST /api/executions/search" do
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
