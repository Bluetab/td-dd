defmodule TdDqWeb.RemediationControllerTest do
  use TdDqWeb.ConnCase


  describe "GET /api/rule_results/:rule_result_id/remediation" do

    setup do
      %{id: id} = rule_result = insert(:rule_result)
      remediation = insert(:remediation, rule_result_id: id)
      %{rule_result: rule_result, remediation: remediation}
    end

    @tag authentication: [role: "admin"]
    test "view rule result remediation", %{conn: conn, rule_result: %{id: rule_result_id}, remediation: %{id: remediation_id}} do
      assert %{"data" => data} =
        conn
        |> get(Routes.rule_result_remediation_path(conn, :show, rule_result_id))
        |> json_response(:ok)

      assert %{"id" => ^remediation_id} = data
    end

    @tag authentication: [role: "admin"]
    test "create rule result remediation", %{conn: conn} do
      %{id: rule_result_id} = rule_result = insert(:rule_result)

      remediation_params = %{
        "rule_result_id" => rule_result_id,
        "remediation" => %{
          "df_name" => "template1",
          "df_content" => %{}
        }
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.rule_result_remediation_path(conn, :create, rule_result_id),
               remediation_params
               )
               |> json_response(:created)

      assert  %{
        "df_name" => "template1",
        "df_content" => %{}
      } = data
    end

    @tag authentication: [role: "admin"]
    test "update rule result remediation", %{conn: conn, rule_result: %{id: rule_result_id}} do

      remediation_params = %{
        "df_name" => "updated_template1",
        "df_content" => %{"text" => "new text"}
      }

      assert %{"data" => data} =
        conn
        |> put(Routes.rule_result_remediation_path(conn, :update, rule_result_id), remediation: remediation_params)
        |> json_response(:ok)

      assert %{
        "df_name" => "updated_template1",
        "df_content" => %{"text" => "new text"}
      } = data
    end
  end
end
