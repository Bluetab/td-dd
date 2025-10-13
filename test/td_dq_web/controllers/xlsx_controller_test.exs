defmodule TdDdWeb.XLSXControllerTest do
  use Oban.Testing, repo: TdDd.Repo, prefix: Application.get_env(:td_dd, Oban)[:prefix]
  use TdDqWeb.ConnCase

  import Mox

  alias XlsxReader

  @moduletag sandbox: :shared
  @file_upload_dir Application.compile_env(:td_dd, :file_upload_dir)
  @rule_implementation_permissions [:manage_quality_rule_implementations, :view_quality_rule]

  setup_all do
    on_exit(fn -> File.rm_rf(@file_upload_dir) end)
    :ok
  end

  describe "xlsx download" do
    setup do
      domain = CacheHelpers.insert_domain()

      details = %{
        "Query" => "Rk9P",
        "baz_title" => "baz"
      }

      details2 = %{
        "foo_title" => %{"x" => "foo"},
        "baz_title" => "bazz",
        "jaz_title" => "jaz"
      }

      result =
        build(:rule_result,
          records: 3245,
          result_type: "percentage",
          errors: 123,
          result: 0,
          details: details
        )

      result2 =
        build(:rule_result,
          records: 3245,
          result_type: "percentage",
          errors: 123,
          result: 0,
          details: details2
        )

      implementations = [
        insert(:implementation,
          domain_id: domain.id,
          results: [result],
          df_content: %{"some_first_field" => "some_first_value"}
        ),
        insert(:implementation,
          domain_id: domain.id,
          results: [result2],
          df_content: %{"some_second_field" => "some_value"}
        ),
        insert(:implementation,
          domain_id: domain.id,
          df_content: %{"some_second_field" => "some_second_value"}
        )
      ]

      [
        implementation:
          insert(:implementation,
            domain_id: domain.id
          ),
        implementations: implementations,
        result: result,
        domain: domain
      ]
    end

    @tag authentication: [role: "admin"]
    test "download all implementations as xlsx", %{
      conn: conn,
      implementation: previous_implementation,
      implementations: new_implementations,
      domain: domain
    } do
      concept_id = System.unique_integer([:positive])
      %{name: concept_name_0} = CacheHelpers.insert_concept(%{id: concept_id})

      concept_id_2 = System.unique_integer([:positive])
      %{name: concept_name_1} = CacheHelpers.insert_concept(%{id: concept_id_2})

      concepts_text = Enum.join(Enum.sort([concept_name_0, concept_name_1]), " | ")

      CacheHelpers.insert_link(
        previous_implementation.id,
        "implementation_ref",
        "business_concept",
        concept_id
      )

      CacheHelpers.insert_link(
        previous_implementation.id,
        "implementation_ref",
        "business_concept",
        concept_id_2
      )

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/implementations/_search", %{size: 10_000, sort: sort, query: query}, _ ->
          assert query == %{
                   bool: %{
                     must: %{match_all: %{}},
                     must_not: %{exists: %{field: "deleted_at"}}
                   }
                 }

          assert sort == ["_score", "implementation_key.sort"]

          SearchHelpers.scroll_response([
            previous_implementation
            | new_implementations
          ])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      [
        %{
          implementation_key: key_0,
          implementation_type: type_0,
          rule: %{name: name_0},
          result_type: result_type_0,
          goal: goal_0,
          minimum: minimum_0,
          inserted_at: inserted_at_0,
          updated_at: updated_at_0
        },
        %{
          implementation_key: key_1,
          implementation_type: type_1,
          rule: %{name: name_1},
          result_type: result_type_1,
          goal: goal_1,
          minimum: minimum_1,
          results: [
            %{
              records: records_1,
              errors: errors_1,
              date: result_date_1,
              details: %{"Query" => query_base64, "baz_title" => detail_field1}
            }
          ],
          inserted_at: inserted_at_1,
          updated_at: updated_at_1
        },
        %{
          implementation_key: key_2,
          implementation_type: type_2,
          rule: %{name: name_2},
          result_type: result_type_2,
          goal: goal_2,
          minimum: minimum_2,
          results: [
            %{
              records: records_2,
              errors: errors_2,
              date: result_date_2,
              details: %{
                "baz_title" => baz_title,
                "foo_title" => foo_title,
                "jaz_title" => jaz_title
              }
            }
          ],
          inserted_at: inserted_at_2,
          updated_at: updated_at_2
        },
        %{
          implementation_key: key_3,
          implementation_type: type_3,
          rule: %{name: name_3},
          result_type: result_type_3,
          goal: goal_3,
          minimum: minimum_3,
          inserted_at: inserted_at_3,
          updated_at: updated_at_3
        }
      ] = [previous_implementation | new_implementations]

      {:ok, query} = Base.decode64(query_base64)

      assert %{resp_body: body} = post(conn, Routes.xlsx_path(conn, :download, %{}))

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)

      assert {:ok, [headers | content]} =
               XlsxReader.sheet(
                 workbook,
                 previous_implementation.df_name
                 |> then(fn
                   nil -> "Sheet"
                   "" -> "Sheet"
                   name -> name
                 end)
               )

      assert headers == [
               "implementation_key",
               "implementation_type",
               "domain_external_id",
               "domain",
               "executable",
               "rule",
               "rule_template",
               "implementation_template",
               "result_type",
               "goal",
               "minimum",
               "records",
               "errors",
               "result",
               "execution",
               "last_execution_at",
               "inserted_at",
               "updated_at",
               "business_concepts",
               "structure_domains",
               "dataset_external_id_1",
               "validation_field_1",
               "result_details_Query",
               "result_details_baz_title",
               "result_details_foo_title",
               "result_details_jaz_title"
             ]

      assert content == [
               [
                 key_0,
                 type_0,
                 domain.external_id,
                 domain.name,
                 "ruleImplementation.props.executable.true",
                 name_0,
                 "",
                 "",
                 result_type_0,
                 to_string(goal_0),
                 to_string(minimum_0),
                 "",
                 "",
                 "",
                 "",
                 "",
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(inserted_at_0)),
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(updated_at_0)),
                 concepts_text,
                 "",
                 "",
                 "",
                 ""
               ],
               [
                 key_1,
                 type_1,
                 domain.external_id,
                 domain.name,
                 "ruleImplementation.props.executable.true",
                 name_1,
                 "",
                 "",
                 result_type_1,
                 to_string(goal_1),
                 to_string(minimum_1),
                 to_string(records_1),
                 to_string(errors_1),
                 "0.00",
                 "quality_result.under_minimum",
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(result_date_1)),
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(inserted_at_1)),
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(updated_at_1)),
                 "",
                 "",
                 "",
                 "",
                 query,
                 detail_field1
               ],
               [
                 key_2,
                 type_2,
                 domain.external_id,
                 domain.name,
                 "ruleImplementation.props.executable.true",
                 name_2,
                 "",
                 "",
                 result_type_2,
                 to_string(goal_2),
                 to_string(minimum_2),
                 to_string(records_2),
                 to_string(errors_2),
                 "0.00",
                 "quality_result.under_minimum",
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(result_date_2)),
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(inserted_at_2)),
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(updated_at_2)),
                 "",
                 "",
                 "",
                 "",
                 "",
                 baz_title,
                 Jason.encode!(foo_title),
                 jaz_title
               ],
               [
                 key_3,
                 type_3,
                 domain.external_id,
                 domain.name,
                 "ruleImplementation.props.executable.true",
                 name_3,
                 "",
                 "",
                 result_type_3,
                 to_string(goal_3),
                 to_string(minimum_3),
                 "",
                 "",
                 "",
                 "",
                 "",
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(inserted_at_3)),
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(updated_at_3)),
                 "",
                 "",
                 "",
                 "",
                 ""
               ]
             ]
    end

    @tag authentication: [role: "admin"]
    test "download implementations with result details only for admin", %{
      conn: conn,
      implementations: implementations,
      domain: domain
    } do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/implementations/_search", _, _ ->
        SearchHelpers.scroll_response(implementations)
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      [
        %{
          implementation_key: key_1,
          implementation_type: type_1,
          rule: %{name: name_1},
          result_type: result_type_1,
          goal: goal_1,
          minimum: minimum_1,
          results: [
            %{
              records: records_1,
              errors: errors_1,
              date: result_date_1,
              details: %{"Query" => query_base64, "baz_title" => detail_field1}
            }
          ],
          inserted_at: inserted_1,
          updated_at: updated_1
        } = implementation,
        %{
          implementation_key: key_2,
          implementation_type: type_2,
          rule: %{name: name_2},
          result_type: result_type_2,
          goal: goal_2,
          minimum: minimum_2,
          results: [
            %{
              records: records_2,
              errors: errors_2,
              date: result_date_2,
              details: %{
                "baz_title" => baz_title,
                "foo_title" => foo_title,
                "jaz_title" => jaz_title
              }
            }
          ],
          inserted_at: inserted_2,
          updated_at: updated_2
        },
        %{
          implementation_key: key_3,
          implementation_type: type_3,
          rule: %{name: name_3},
          result_type: result_type_3,
          goal: goal_3,
          minimum: minimum_3,
          inserted_at: inserted_3,
          updated_at: updated_3
        }
      ] = implementations

      {:ok, query} = Base.decode64(query_base64)

      assert %{resp_body: body} = post(conn, Routes.xlsx_path(conn, :download, %{}))

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)

      assert {:ok, [headers | content]} =
               XlsxReader.sheet(
                 workbook,
                 implementation.df_name
                 |> then(fn
                   nil -> "Sheet"
                   "" -> "Sheet"
                   name -> name
                 end)
               )

      assert headers == [
               "implementation_key",
               "implementation_type",
               "domain_external_id",
               "domain",
               "executable",
               "rule",
               "rule_template",
               "implementation_template",
               "result_type",
               "goal",
               "minimum",
               "records",
               "errors",
               "result",
               "execution",
               "last_execution_at",
               "inserted_at",
               "updated_at",
               "business_concepts",
               "structure_domains",
               "dataset_external_id_1",
               "validation_field_1",
               "result_details_Query",
               "result_details_baz_title",
               "result_details_foo_title",
               "result_details_jaz_title"
             ]

      assert content == [
               [
                 key_1,
                 type_1,
                 domain.external_id,
                 domain.name,
                 "ruleImplementation.props.executable.true",
                 name_1,
                 "",
                 "",
                 result_type_1,
                 to_string(goal_1),
                 to_string(minimum_1),
                 to_string(records_1),
                 to_string(errors_1),
                 "0.00",
                 "quality_result.under_minimum",
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(result_date_1)),
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(inserted_1)),
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(updated_1)),
                 "",
                 "",
                 "",
                 "",
                 query,
                 detail_field1
               ],
               [
                 key_2,
                 type_2,
                 domain.external_id,
                 domain.name,
                 "ruleImplementation.props.executable.true",
                 name_2,
                 "",
                 "",
                 result_type_2,
                 to_string(goal_2),
                 to_string(minimum_2),
                 to_string(records_2),
                 to_string(errors_2),
                 "0.00",
                 "quality_result.under_minimum",
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(result_date_2)),
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(inserted_2)),
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(updated_2)),
                 "",
                 "",
                 "",
                 "",
                 "",
                 baz_title,
                 Jason.encode!(foo_title),
                 jaz_title
               ],
               [
                 key_3,
                 type_3,
                 domain.external_id,
                 domain.name,
                 "ruleImplementation.props.executable.true",
                 name_3,
                 "",
                 "",
                 result_type_3,
                 to_string(goal_3),
                 to_string(minimum_3),
                 "",
                 "",
                 "",
                 "",
                 "",
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(inserted_3)),
                 TdDd.Helpers.shift_zone(DateTime.to_iso8601(updated_3)),
                 "",
                 "",
                 "",
                 "",
                 ""
               ]
             ]
    end

    @tag authentication: [
           role: "non-admin",
           permissions: @rule_implementation_permissions ++ [:manage_segments]
         ]
    test "download implementations with result details for non-admin", %{
      conn: conn,
      implementations: implementations,
      domain: domain
    } do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/implementations/_search", _, opts ->
        assert opts == [params: %{"scroll" => "1m"}]
        SearchHelpers.scroll_response(implementations)
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      [
        %{
          implementation_key: key_1,
          implementation_type: type_1,
          rule: %{name: name_1},
          result_type: result_type_1,
          goal: goal_1,
          minimum: minimum_1,
          results: [
            %{
              records: records_1,
              errors: errors_1,
              date: result_date_1,
              details: %{"Query" => query_base64, "baz_title" => detail_field1}
            }
          ],
          inserted_at: inserted_1,
          updated_at: updated_1
        } = implementation,
        %{
          implementation_key: key_2,
          implementation_type: type_2,
          rule: %{name: name_2},
          result_type: result_type_2,
          goal: goal_2,
          minimum: minimum_2,
          results: [
            %{
              records: records_2,
              errors: errors_2,
              date: result_date_2,
              details: %{
                "baz_title" => baz_title,
                "foo_title" => foo_title,
                "jaz_title" => jaz_title
              }
            }
          ],
          inserted_at: inserted_2,
          updated_at: updated_2
        },
        %{
          implementation_key: key_3,
          implementation_type: type_3,
          rule: %{name: name_3},
          result_type: result_type_3,
          goal: goal_3,
          minimum: minimum_3,
          inserted_at: inserted_3,
          updated_at: updated_3
        }
      ] = implementations

      {:ok, query} = Base.decode64(query_base64)

      assert %{resp_body: body} = post(conn, Routes.xlsx_path(conn, :download, %{}))

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)

      assert {:ok, [headers | content]} =
               XlsxReader.sheet(
                 workbook,
                 implementation.df_name
                 |> then(fn
                   nil -> "Sheet"
                   "" -> "Sheet"
                   name -> name
                 end)
               )

      assert headers == [
               "implementation_key",
               "implementation_type",
               "domain_external_id",
               "domain",
               "executable",
               "rule",
               "rule_template",
               "implementation_template",
               "result_type",
               "goal",
               "minimum",
               "records",
               "errors",
               "result",
               "execution",
               "last_execution_at",
               "inserted_at",
               "updated_at",
               "business_concepts",
               "structure_domains",
               "dataset_external_id_1",
               "validation_field_1",
               "result_details_Query",
               "result_details_baz_title",
               "result_details_foo_title",
               "result_details_jaz_title"
             ]

      assert content == [
               [
                 key_1,
                 type_1,
                 domain.external_id,
                 domain.name,
                 "ruleImplementation.props.executable.true",
                 name_1,
                 "",
                 "",
                 result_type_1,
                 to_string(goal_1),
                 to_string(minimum_1),
                 to_string(records_1),
                 to_string(errors_1),
                 "0.00",
                 "quality_result.under_minimum",
                 TdDd.Helpers.shift_zone(result_date_1),
                 TdDd.Helpers.shift_zone(inserted_1),
                 TdDd.Helpers.shift_zone(updated_1),
                 "",
                 "",
                 "",
                 "",
                 query,
                 detail_field1
               ],
               [
                 key_2,
                 type_2,
                 domain.external_id,
                 domain.name,
                 "ruleImplementation.props.executable.true",
                 name_2,
                 "",
                 "",
                 result_type_2,
                 to_string(goal_2),
                 to_string(minimum_2),
                 to_string(records_2),
                 to_string(errors_2),
                 "0.00",
                 "quality_result.under_minimum",
                 TdDd.Helpers.shift_zone(result_date_2),
                 TdDd.Helpers.shift_zone(inserted_2),
                 TdDd.Helpers.shift_zone(updated_2),
                 "",
                 "",
                 "",
                 "",
                 "",
                 baz_title,
                 Jason.encode!(foo_title),
                 jaz_title
               ],
               [
                 key_3,
                 type_3,
                 domain.external_id,
                 domain.name,
                 "ruleImplementation.props.executable.true",
                 name_3,
                 "",
                 "",
                 result_type_3,
                 to_string(goal_3),
                 to_string(minimum_3),
                 "",
                 "",
                 "",
                 "",
                 "",
                 TdDd.Helpers.shift_zone(inserted_3),
                 TdDd.Helpers.shift_zone(updated_3),
                 "",
                 "",
                 "",
                 "",
                 ""
               ]
             ]
    end
  end

  describe "xlsx upload" do
    @tag authentication: [role: "admin"]
    test "admin will queue upload job", %{conn: conn, claims: claims} do
      filename = "upload_tiny.xlsx"
      path = "test/fixtures/xlsx/#{filename}"
      job_path = "test/upload/#{filename}"

      lang = "en"
      auto_publish = "true"

      %{
        user_id: user_id,
        user_name: user_name,
        role: role,
        jti: jti
      } = claims

      assert conn
             |> post(Routes.xlsx_path(conn, :upload),
               implementations: upload(path),
               lang: lang,
               auto_publish: auto_publish
             )
             |> response(:ok)

      assert [
               %Oban.Job{
                 state: "available",
                 queue: "xlsx_implementations_upload_queue",
                 worker: "TdDq.XLSX.Jobs.UploadWorker",
                 args: %{
                   "opts" => %{
                     "auto_publish" => ^auto_publish,
                     "claims" => %{
                       "jti" => ^jti,
                       "role" => ^role,
                       "user_id" => ^user_id,
                       "user_name" => ^user_name
                     },
                     "lang" => ^lang
                   },
                   "path" => ^job_path
                 }
               }
             ] = all_enqueued()
    end

    @tag authentication: [role: "user"]
    test "user without permission cannot upload", %{conn: conn} do
      filename = "upload_tiny.xlsx"
      path = "test/fixtures/xlsx/#{filename}"

      assert conn
             |> post(Routes.xlsx_path(conn, :upload),
               implementations: upload(path)
             )
             |> response(:forbidden)
    end

    for permission <- [
          :manage_ruleless_implementations,
          :manage_quality_rule_implementations,
          :manage_raw_quality_rule_implementations
        ] do
      @tag authentication: [role: "admin", permissions: [permission]]
      test "user with #{permission} permission can initiate upload", %{conn: conn, claims: claims} do
        filename = "upload_tiny.xlsx"
        path = "test/fixtures/xlsx/#{filename}"
        job_path = "test/upload/#{filename}"

        lang = "en"
        auto_publish = "true"

        %{
          user_id: user_id,
          user_name: user_name,
          role: role,
          jti: jti
        } = claims

        assert conn
               |> post(Routes.xlsx_path(conn, :upload),
                 implementations: upload(path),
                 lang: lang,
                 auto_publish: auto_publish
               )
               |> response(:ok)

        assert [
                 %Oban.Job{
                   state: "available",
                   queue: "xlsx_implementations_upload_queue",
                   worker: "TdDq.XLSX.Jobs.UploadWorker",
                   args: %{
                     "opts" => %{
                       "auto_publish" => ^auto_publish,
                       "claims" => %{
                         "jti" => ^jti,
                         "role" => ^role,
                         "user_id" => ^user_id,
                         "user_name" => ^user_name
                       },
                       "lang" => ^lang
                     },
                     "path" => ^job_path
                   }
                 }
               ] = all_enqueued()
      end
    end
  end

  describe "xlsx upload jobs" do
    @tag authentication: [role: "admin"]
    test "can list only their own upload jobs", %{conn: conn, claims: claims} do
      job = insert(:implementation_upload_job, user_id: claims.user_id)
      _other_job = insert(:implementation_upload_job, user_id: claims.user_id + 1)

      assert %{"data" => [%{"id" => id}]} =
               conn
               |> get(Routes.xlsx_path(conn, :upload_jobs))
               |> json_response(:ok)

      assert id == job.id
    end

    @tag authentication: [role: "admin"]
    test "return latest status for upload job", %{conn: conn, claims: claims} do
      job = insert(:implementation_upload_job, user_id: claims.user_id)
      insert(:implementation_upload_event, job_id: job.id, status: "PENDING")

      %{inserted_at: latest_event_at_ts} =
        insert(:implementation_upload_event,
          job_id: job.id,
          status: "COMPLETED",
          response: %{"message" => "Completed"}
        )

      latest_event_at = DateTime.to_iso8601(latest_event_at_ts)

      assert %{
               "data" => [
                 %{
                   "latest_status" => "COMPLETED",
                   "latest_event_at" => ^latest_event_at,
                   "latest_event_response" => %{"message" => "Completed"}
                 }
               ]
             } =
               conn
               |> get(Routes.xlsx_path(conn, :upload_jobs))
               |> json_response(:ok)
    end
  end

  describe "xlsx upload job" do
    @tag authentication: [role: "admin"]
    test "can get upload job", %{conn: conn, claims: claims} do
      %{id: job_id} = insert(:implementation_upload_job, user_id: claims.user_id)
      %{id: event_id} = insert(:implementation_upload_event, job_id: job_id)

      assert %{"data" => response} =
               conn
               |> get(Routes.xlsx_path(conn, :upload_job, job_id))
               |> json_response(:ok)

      assert %{"id" => ^job_id, "events" => [%{"id" => ^event_id}]} = response
    end
  end
end
