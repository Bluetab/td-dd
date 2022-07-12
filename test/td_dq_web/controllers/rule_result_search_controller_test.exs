defmodule TdDqWeb.RuleResultSearchControllerTest do
  use TdDqWeb.ConnCase

  describe "POST /api/rule_results/search" do
    @tag authentication: [role: "service"]
    test "service account can view rule results", %{conn: conn} do
      implementation_135 =
        %{id: implementation_id_135} =
        insert(:implementation, implementation_key: "ri135", status: :published)

      implementation_136 =
        %{id: implementation_id_136} =
        insert(:implementation, implementation_key: "ri136", status: :published)

      %{id: id_135} = insert(:rule_result, implementation: implementation_135)
      %{id: id_136_1} = insert(:rule_result, implementation: implementation_136)
      %{id: id_136_2} = insert(:rule_result, implementation: implementation_136)

      resp_conn = post(conn, Routes.rule_result_search_path(conn, :create))

      assert %{"data" => rule_results} = json_response(resp_conn, :ok)
      assert ["3"] = Plug.Conn.get_resp_header(resp_conn, "x-total-count")

      assert [
               %{"implementation_id" => ^implementation_id_135, "id" => ^id_135},
               %{"implementation_id" => ^implementation_id_136, "id" => ^id_136_1},
               %{"implementation_id" => ^implementation_id_136, "id" => ^id_136_2}
             ] = rule_results
    end
  end
end
