defmodule TdDqWeb.RemediationControllerTest do
  use TdDqWeb.ConnCase

  setup tags do

    remediation_template = %{
      name: "remediation_template",
      label: "remediation_template",
      scope: "remediation",
      content: [
        %{
          "name" => "grupo_principal",
          "fields" => [
            %{
              "name" => "texto",
              "type" => "string",
              "label" => "Text",
              "values" => nil,
              "widget" => "string",
              "default" => "",
              "cardinality" => "?",
              "description" => "texto"
            }
          ]
        }
      ]
    }
    CacheHelpers.insert_template(remediation_template)
    domain = Map.get(tags, :domain, CacheHelpers.insert_domain())
    rule = insert(:rule, domain_id: domain.id)
    %{id: rule_result_id} = rule_result = insert(:rule_result, rule: rule)
    remediation = insert(:remediation, rule_result_id: rule_result_id)
    %{rule_result: rule_result, remediation: remediation}

    %{domain: domain, rule: rule, template: remediation_template, remediation: remediation, rule_result: rule_result}
  end

  describe "GET /api/rule_results/:rule_result_id/remediation" do

    @tag authentication: [role: "admin"]
    test "remediation from inexistent rule result renders not found", %{conn: conn} do
      assert conn
        |> get(Routes.rule_result_remediation_path(conn, :show, 12_345))
        |> json_response(:not_found)
    end

    @tag authentication: [role: "admin"]
    test "inexistent remediation from existing rule result renders not found", %{conn: conn, rule: rule} do
      %{id: rule_result_id} = insert(:rule_result, rule: rule)

      assert conn
        |> get(Routes.rule_result_remediation_path(conn, :show, rule_result_id))
        |> json_response(:not_found)
    end

    @tag authentication: [role: "user"]
    test "user without manage_remediation permission cannot view remediation", %{conn: conn, rule_result: %{id: rule_result_id}} do
      assert conn
        |> get(Routes.rule_result_remediation_path(conn, :show, rule_result_id))
        |> json_response(:forbidden)
    end

    @tag authentication: [role: "user", permissions: ["manage_remediations"]]
    test "user with manage_remediation permission can view remediation", %{conn: conn, rule_result: %{id: rule_result_id}, remediation: %{id: remediation_id}} do
      assert %{"data" => data} =
        conn
        |> get(Routes.rule_result_remediation_path(conn, :show, rule_result_id))
        |> json_response(:ok)

      assert %{"id" => ^remediation_id} = data
    end

    @tag authentication: [role: "user", permissions: ["manage_remediations"]]
    test "user with manage_remediation permission can create remediation", %{conn: conn, rule_result: %{id: rule_result_id}} do

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

    @tag authentication: [role: "user", permissions: ["manage_remediations"]]
    test "user with manage_remediation permission can update remediation", %{conn: conn, template: %{name: df_name}, rule_result: %{id: rule_result_id}} do

      remediation_params = %{
        "df_name" => df_name,
        "df_content" => %{"text" => "new text"}
      }

      assert %{"data" => data} =
        conn
        |> put(Routes.rule_result_remediation_path(conn, :update, rule_result_id), remediation: remediation_params)
        |> json_response(:ok)

      assert %{
        "df_name" => ^df_name,
        "df_content" => %{"text" => "new text"}
      } = data
    end

    @tag authentication: [role: "user", permissions: ["manage_remediations"]]
    test "deletes chosen source", %{conn: conn, rule_result: %{id: rule_result_id}} do
      conn = delete(conn, Routes.rule_result_remediation_path(conn, :delete, rule_result_id))
      assert response(conn, 204)

      assert conn
        |> get(Routes.rule_result_remediation_path(conn, :show, rule_result_id))
        |> json_response(:not_found)
    end

  end
end
