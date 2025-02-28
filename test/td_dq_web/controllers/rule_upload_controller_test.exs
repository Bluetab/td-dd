defmodule TdDqWeb.RuleUploadControllerTest do
  use TdDqWeb.ConnCase

  @moduletag sandbox: :shared

  @hierarchy_template [
    %{
      "name" => "group",
      "fields" => [
        %{
          "cardinality" => "?",
          "name" => "hierarchy_name_1",
          "label" => "Hierarchy name 1",
          "type" => "hierarchy",
          "values" => %{"hierarchy" => %{"id" => 1}},
          "widget" => "dropdown"
        },
        %{
          "cardinality" => "*",
          "name" => "hierarchy_name_2",
          "label" => "Hierarchy name 2",
          "type" => "hierarchy",
          "values" => %{"hierarchy" => %{"id" => 1}},
          "widget" => "dropdown"
        }
      ]
    }
  ]

  setup do
    start_supervised!(TdDq.Cache.RuleLoader)

    CacheHelpers.insert_template(scope: "dq", name: "bar_template")

    CacheHelpers.insert_template(scope: "dq", name: "hierarchies", content: @hierarchy_template)

    CacheHelpers.insert_domain(%{external_id: "zoo_domain"})

    hierarchy = create_hierarchy()
    CacheHelpers.insert_hierarchy(hierarchy)

    :ok
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
      assert length(ids) == 4
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
      assert length(errors) == 4
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

      assert error == %{
               "error" => "missing_required_columns",
               "expected" => "name, domain_external_id",
               "found" => "with_no_required_headers, foo, bar"
             }
    end
  end

  defp create_hierarchy do
    hierarchy_id = 1

    %{
      id: hierarchy_id,
      name: "name_#{hierarchy_id}",
      nodes: [
        build(:hierarchy_node, %{
          node_id: 1,
          parent_id: nil,
          name: "father",
          path: "/father",
          hierarchy_id: hierarchy_id
        }),
        build(:hierarchy_node, %{
          node_id: 2,
          parent_id: 1,
          name: "children_1",
          path: "/father/children_1",
          hierarchy_id: hierarchy_id
        }),
        build(:hierarchy_node, %{
          node_id: 3,
          parent_id: 1,
          name: "children_2",
          path: "/father/children_2",
          hierarchy_id: hierarchy_id
        }),
        build(:hierarchy_node, %{
          node_id: 4,
          parent_id: nil,
          name: "children_2",
          path: "/children_2",
          hierarchy_id: hierarchy_id
        })
      ]
    }
  end
end
