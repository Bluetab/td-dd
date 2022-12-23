defmodule TdDqWeb.RemediationControllerTest do
  use TdDqWeb.ConnCase

  setup_all do
    start_supervised(TdDq.Cache.RuleLoader)
    start_supervised(TdDd.Search.MockIndexWorker)
    :ok
  end

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
    %{id: rule_result_id} = rule_result = insert(:rule_result, rule: rule, implementation: build(:implementation))

    remediation = insert(:remediation, rule_result_id: rule_result_id)

    %{rule_result: rule_result, remediation: remediation}

    [
      domain: domain,
      rule: rule,
      template: remediation_template,
      remediation: remediation,
      rule_result: rule_result
    ]
  end

  describe "GET /api/rule_results/:rule_result_id/remediation" do
    @tag authentication: [role: "admin"]
    test "remediation from inexistent rule result renders not found", %{conn: conn} do
      assert conn
             |> get(Routes.rule_result_remediation_path(conn, :show, 12_345))
             |> json_response(:not_found)
    end

    @tag authentication: [role: "admin"]
    test "inexistent remediation from existing rule result renders actions", %{
      conn: conn,
      rule: rule
    } do
      %{id: rule_result_id} = insert(:rule_result, rule: rule)

      actions = %{
        "create" => %{
          "href" => "/api/rule_results/#{rule_result_id}/remediation",
          "method" => "POST"
        },
        "delete" => %{
          "href" => "/api/rule_results/#{rule_result_id}/remediation",
          "method" => "DELETE"
        },
        "show" => %{
          "href" => "/api/rule_results/#{rule_result_id}/remediation",
          "method" => "GET"
        },
        "update" => %{
          "href" => "/api/rule_results/#{rule_result_id}/remediation",
          "method" => "PATCH"
        }
      }

      assert %{"_actions" => actions_response, "data" => nil} =
               conn
               |> get(Routes.rule_result_remediation_path(conn, :show, rule_result_id))
               |> json_response(:ok)

      assert ^actions = actions_response
    end

    @tag authentication: [role: "user"]
    test "user without manage_remediations can view remediation", %{
      conn: conn,
      rule_result: %{id: rule_result_id},
      remediation: %{id: remediation_id}
    } do
      assert %{"data" => data} =
               conn
               |> get(Routes.rule_result_remediation_path(conn, :show, rule_result_id))
               |> json_response(:ok)

      %{"id" => ^remediation_id} = data
    end

    @tag authentication: [role: "user", permissions: ["manage_remediations"]]
    test "user with manage_remediations permission can view remediation", %{
      conn: conn,
      rule_result: %{id: rule_result_id},
      remediation: %{id: remediation_id}
    } do
      assert %{"data" => data} =
               conn
               |> get(Routes.rule_result_remediation_path(conn, :show, rule_result_id))
               |> json_response(:ok)

      assert %{"id" => ^remediation_id} = data
    end

    @tag authentication: [role: "user", permissions: ["manage_remediations"]]
    test "user with manage_remediations permission can create remediation", %{
      conn: conn,
      rule_result: %{id: rule_result_id}
    } do
      remediation_params = %{
        "rule_result_id" => rule_result_id,
        "remediation" => %{
          "df_name" => "template1",
          "df_content" => %{}
        }
      }

      assert %{"data" => data} =
               conn
               |> post(
                 Routes.rule_result_remediation_path(conn, :create, rule_result_id),
                 remediation_params
               )
               |> json_response(:created)

      assert %{
               "df_name" => "template1",
               "df_content" => %{}
             } = data
    end

    @tag authentication: [role: "user", permissions: ["manage_remediations"]]
    test "user with manage_remediations permission can update remediation", %{
      conn: conn,
      template: %{name: df_name},
      rule_result: %{id: rule_result_id}
    } do
      remediation_params = %{
        "df_name" => df_name,
        "df_content" => %{"text" => "new text"}
      }

      assert %{"data" => data} =
               conn
               |> put(Routes.rule_result_remediation_path(conn, :update, rule_result_id),
                 remediation: remediation_params
               )
               |> json_response(:ok)

      assert %{
               "df_name" => ^df_name,
               "df_content" => %{"text" => "new text"}
             } = data
    end

    @tag authentication: [role: "user", permissions: ["manage_remediations"]]
    test "deletes chosen source", %{conn: conn, rule_result: %{id: rule_result_id}} do
      assert conn
             |> delete(Routes.rule_result_remediation_path(conn, :delete, rule_result_id))
             |> response(:no_content)

      assert %{"data" => nil} =
               conn
               |> get(Routes.rule_result_remediation_path(conn, :show, rule_result_id))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "delete a rule result also have to delete remediation", %{
      conn: conn,
      rule_result: %{id: rule_result_id}
    } do
      assert conn
             |> delete(Routes.rule_result_remediation_path(conn, :delete, rule_result_id))
             |> response(:no_content)

      assert %{"data" => nil} =
               conn
               |> get(Routes.rule_result_remediation_path(conn, :show, rule_result_id))
               |> json_response(:ok)
    end
  end
end
