defmodule TdDdWeb.ImplementationUploadControllerTest do
  use TdDqWeb.ConnCase

  @moduletag sandbox: :shared

  setup_all do
    start_supervised!(TdDd.Search.MockIndexWorker)
    :ok
  end

  setup context do
    template = CacheHelpers.insert_template(scope: "dq", name: "bar_template")
    rule = insert_rule(context)

    [template: template, rule: rule]
  end

  # This domain comes from TdDqWeb.ConnCase setup tags if
  # @tag authentication with permissions is used
  defp insert_rule(%{domain: %{id: domain_id}}) do
    insert(:rule, name: "rule_foo", domain_id: domain_id)
  end

  defp insert_rule(_context_without_domain) do
    insert(:rule, name: "rule_foo")
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

    @tag authentication: [role: "user"]
    test "return error if user has no permisssions", %{conn: conn} do
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

      assert %{"ids" => [], "errors" => errors} = data
      assert length(errors) == 3

      Enum.each(errors, fn %{"message" => message} ->
        assert ^message = %{"implementation" => ["forbidden"]}
      end)
    end

    @tag authentication: [role: "user", permissions: [:manage_basic_implementations]]
    test "user can upload implementations if it has permissions", %{
      conn: conn
    } do
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
    test "uploads implementations with domain selection template", %{conn: conn} do
      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations.csv",
          path: "test/fixtures/implementations/implementations_template_with_domain.csv"
        }
      }

      %{id: domain_id1} = CacheHelpers.insert_domain(external_id: "domain_external_id1")
      %{id: domain_id2} = CacheHelpers.insert_domain(external_id: "domain_external_id2")

      template_content = [
        %{
          "fields" => [
            %{
              "name" => "my_domain1",
              "type" => "domain",
              "label" => "My domain",
              "values" => nil,
              "widget" => "dropdown",
              "default" => "",
              "cardinality" => "?",
              "subscribable" => false
            },
            %{
              "name" => "my_domain2",
              "type" => "domain",
              "label" => "My domain2",
              "values" => nil,
              "widget" => "dropdown",
              "default" => "",
              "cardinality" => "?",
              "subscribable" => false
            }
          ],
          "name" => "group_name0"
        }
      ]

      CacheHelpers.insert_template(
        scope: "ri",
        content: template_content,
        name: "domain_template"
      )

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => [id1, id2, id3], "errors" => []} = data

      assert %{
               "data" => %{
                 "df_content" => df_content
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, id1))
               |> json_response(:ok)

      assert %{"my_domain1" => ^domain_id1, "my_domain2" => ^domain_id2} = df_content

      assert %{
               "data" => %{
                 "df_content" => df_content2
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, id2))
               |> json_response(:ok)

      assert %{"my_domain1" => ^domain_id1, "my_domain2" => nil} = df_content2

      assert %{
               "data" => %{
                 "df_content" => df_content3
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, id3))
               |> json_response(:ok)

      assert %{"my_domain1" => nil, "my_domain2" => nil} = df_content3
    end

    @tag authentication: [role: "admin"]
    test "uploads implementations with template with enriched text", %{conn: conn} do
      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations.csv",
          path: "test/fixtures/implementations/implementations_template_with_enriched_text.csv"
        }
      }

      template_content = [
        %{
          "fields" => [
            %{
              "name" => "enriched_field",
              "type" => "enriched_text",
              "label" => "Enriched field",
              "values" => nil,
              "widget" => "enriched_text",
              "default" => "",
              "cardinality" => "?",
              "subscribable" => false
            }
          ],
          "name" => "group_name0"
        }
      ]

      CacheHelpers.insert_template(
        scope: "ri",
        content: template_content,
        name: "enriched_template"
      )

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => [id1, id2], "errors" => []} = data

      assert %{
               "data" => %{
                 "df_content" => df_content
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, id1))
               |> json_response(:ok)

      assert %{
               "enriched_field" => %{
                 "object" => "value",
                 "document" => %{
                   "data" => %{},
                   "nodes" => [
                     %{
                       "data" => %{},
                       "type" => "paragraph",
                       "object" => "block",
                       "nodes" => [
                         %{
                           "text" => "foo",
                           "marks" => [],
                           "object" => "text"
                         }
                       ]
                     }
                   ],
                   "object" => "document"
                 }
               }
             } = df_content

      assert %{
               "data" => %{
                 "df_content" => df_content2
               }
             } =
               conn
               |> get(Routes.implementation_path(conn, :show, id2))
               |> json_response(:ok)

      assert %{"enriched_field" => %{}} = df_content2
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

    @tag authentication: [role: "user"]
    test "user can upload implementations without rules if it has permissions", %{
      conn: conn,
      claims: claims
    } do
      %{id: domain_id} = CacheHelpers.insert_domain(external_id: "some_domain_id")

      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations_without_rules.csv",
          path: "test/fixtures/implementations/implementations_without_rules.csv"
        }
      }

      CacheHelpers.put_session_permissions(claims, domain_id, [
        :manage_basic_implementations,
        :manage_ruleless_implementations
      ])

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_upload_path(conn, :create), attrs)
               |> json_response(:ok)

      assert %{"ids" => ids, "errors" => []} = data
      assert length(ids) == 3
    end

    @tag authentication: [role: "admin"]
    test "uploads implementations with and without rules", %{conn: conn} do
      CacheHelpers.insert_domain(external_id: "some_domain_id")

      attrs = %{
        implementations: %Plug.Upload{
          filename: "implementations_without_rules.csv",
          path: "test/fixtures/implementations/implementations_with_and_without_rules.csv"
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

      assert error == %{
               "error" => "missing_required_columns",
               "expected" => "implementation_key, result_type, goal, minimum",
               "found" => "with_no_required_headers, foo, bar"
             }
    end
  end
end
