defmodule TdDqWeb.RuleUploadControllerTest do
  use TdDqWeb.ConnCase

  @moduletag sandbox: :shared

  setup_all do
    start_supervised!(TdDq.Cache.RuleLoader)
    start_supervised!(TdDd.Search.MockIndexWorker)
    :ok
  end

  setup do
    template = CacheHelpers.insert_template(scope: "dq", name: "bar_template")
    domain = CacheHelpers.insert_domain(%{external_id: "zoo_domain"})
    [template: template, domain: domain]
  end

  describe "upload" do
    @tag authentication: [role: "admin"]
    test "upload rules", %{conn: conn} do
      attrs = %{
        rules: %Plug.Upload{
          filename: "rules.csv",
          path: "test/fixtures/rules/rules.csv"
        }
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.rule_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => ids, "errors" => []} = data
      assert length(ids) == 3
    end

    @tag authentication: [role: "admin"]
    test "renders errors", %{conn: conn} do
      attrs = %{
        rules: %Plug.Upload{
          filename: "rules.csv",
          path: "test/fixtures/rules/rules_errors.csv"
        }
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.rule_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"errors" => errors, "ids" => []} = data
      assert length(errors) == 3
    end

    @tag authentication: [role: "admin"]
    test "renders errors with malformed file", %{conn: conn} do
      attrs = %{
        rules: %Plug.Upload{
          filename: "rules.csv",
          path: "test/fixtures/rules/rules_malformed.csv"
        }
      }

      assert %{"error" => error} =
               conn
               |> post(Routes.rule_upload_path(conn, :create), attrs)
               |> json_response(:unprocessable_entity)

      assert %{"error" => "misssing_required_columns"} = error
    end
  end
end
