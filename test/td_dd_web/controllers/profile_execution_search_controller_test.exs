defmodule TdDdWeb.ProfileExecutionSearchControllerTest do
  use TdDdWeb.ConnCase

  setup do
    execution =
      insert(:profile_execution,
        profile_group: build(:profile_execution_group),
        data_structure: build(:data_structure)
      )

    [execution: execution]
  end

  describe "POST /api/profile_executions/search" do
    @tag authentication: [role: "service"]
    test "service account can search executions", %{conn: conn} do
      params = %{"foo" => "bar"}

      assert %{"data" => [_]} =
               conn
               |> post(Routes.profile_execution_search_path(conn, :create), params)
               |> json_response(:ok)
    end
  end
end
