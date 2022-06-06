defmodule TdDdWeb.ImplementationUploadControllerTest do
  use TdDqWeb.ConnCase

  @moduletag sandbox: :shared

  setup_all do
    start_supervised!(TdDd.Search.MockIndexWorker)
    :ok
  end

  setup do
    template = CacheHelpers.insert_template(scope: "dq", name: "bar_template")
    rule = insert(:rule, name: "rule_foo")
    [template: template, rule: rule]
  end

  describe "upload" do
    @tag authentication: [role: "admin"]
    test "uploads implementations", %{conn: conn} do
      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations.csv",
          path: "test/fixtures/implementations/implementations.csv"
        }
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => ids, "errors" => []} = data
      assert length(ids) == 3
    end

    @tag authentication: [role: "admin"]
    test "uploads implementations without rules", %{conn: conn} do
      CacheHelpers.insert_domain(external_id: "some_domain_id")

      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations_without_rules.csv",
          path: "test/fixtures/implementations/implementations_without_rules.csv"
        }
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => ids, "errors" => []} = data
      assert length(ids) == 3
    end

    @tag authentication: [role: "admin"]
    test "renders errors", %{conn: conn} do
      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations.csv",
          path: "test/fixtures/implementations/implementations_errors.csv"
        }
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"errors" => errors, "ids" => []} = data
      assert length(errors) == 4
    end

    @tag authentication: [role: "admin"]
    test "renders error with malformed file", %{conn: conn} do
      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations.csv",
          path: "test/fixtures/implementations/implementations_malformed.csv"
        }
      }

      assert %{"error" => error} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:unprocessable_entity)

      assert %{"error" => "misssing_required_columns"} = error
    end
  end
end
