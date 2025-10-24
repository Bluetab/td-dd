defmodule TdDq.XLSX.BulkLoadTest do
  use TdDd.DataCase

  alias TdDq.Implementations
  alias TdDq.Implementations.UploadEvents
  alias TdDq.XLSX.BulkLoad

  @moduletag sandbox: :shared

  setup do
    headers = [
      "implementation_key",
      "implementation_template",
      "result_type",
      "goal",
      "minimum",
      "rule",
      "executable",
      "records"
    ]

    CacheHelpers.put_i18n_messages(
      "en",
      Enum.map(
        headers,
        &%{message_id: "ruleImplementations.props.#{&1}", definition: "english_#{&1}"}
      ) ++
        [
          %{
            message_id: "ruleImplementations.props.result_type.percentage",
            definition: "translated_percentage"
          },
          %{
            message_id: "fields.String Field",
            definition: "english_string_field"
          },
          %{
            message_id: "fields.Numeric Field",
            definition: "english_numeric_field"
          }
        ]
    )

    template =
      CacheHelpers.insert_template(
        name: "impl_template",
        scope: "ri",
        content: [
          %{
            "name" => "group",
            "fields" => [
              %{
                "name" => "string_field",
                "type" => "string",
                "label" => "String Field",
                "cardinality" => "?"
              },
              %{
                "name" => "numeric_field",
                "type" => "integer",
                "label" => "Numeric Field",
                "cardinality" => "?"
              }
            ]
          }
        ]
      )

    %{id: domain_id} = domain = CacheHelpers.insert_domain(name: "impl_domain")

    insert(:implementation,
      implementation_key: "existing_impl",
      df_name: "impl_template",
      df_content: %{},
      domain_id: domain_id,
      domain: domain
    )

    %{id: job_id} = insert(:implementation_upload_job)

    [
      opts: %{claims: build(:claims), lang: "en", to_status: "draft", job_id: job_id},
      domain: domain,
      template: template
    ]
  end

  describe "bulk_load/2" do
    test "insert new implementation", %{opts: opts, domain: domain} do
      sheets = %{
        "Sheet1" =>
          {[
             "english_implementation_key",
             "english_implementation_template",
             "english_result_type",
             "english_goal",
             "english_minimum",
             "domain_external_id",
             "english_executable",
             "english_records",
             "english_string_field"
           ],
           [
             [
               "impl_key",
               "impl_template",
               "translated_percentage",
               75,
               50,
               domain.external_id,
               "executable",
               "records",
               "string_value"
             ]
           ]}
      }

      assert {:ok,
              %{
                error_count: 0,
                insert_count: 1,
                update_count: 0,
                unchanged_count: 0,
                invalid_sheet_count: 0
              }} =
               BulkLoad.bulk_load(sheets, opts)

      assert %{events: events} =
               UploadEvents.get_job(opts.job_id)

      assert [
               %{
                 response: %{
                   "details" => %{"implementation_key" => "impl_key"},
                   "row_number" => 2,
                   "sheet" => "Sheet1",
                   "type" => "created"
                 },
                 status: "INFO"
               }
             ] = events
    end

    test "update implementation without changing missing template column", %{
      opts: opts,
      domain: domain,
      template: template
    } do
      numeric_field_value = 8

      %{
        id: impl_id,
        implementation_key: impl_key,
        result_type: result_type,
        goal: goal,
        minimum: minimum
      } =
        insert(:implementation,
          implementation_key: "impl_key",
          df_name: template.name,
          df_content: %{
            "string_field" => %{"value" => "string_value", "origin" => "file"},
            "numeric_field" => %{"value" => numeric_field_value, "origin" => "user"}
          },
          template: template,
          domain_id: domain.id
        )

      sheets = %{
        template.name =>
          {[
             "english_implementation_key",
             "english_implementation_template",
             "english_result_type",
             "english_goal",
             "english_minimum",
             "domain_external_id",
             "english_string_field"
           ],
           [
             [
               impl_key,
               template.name,
               result_type,
               goal,
               minimum,
               domain.external_id,
               "string_value_change"
             ]
           ]}
      }

      assert {
               :ok,
               %{
                 error_count: 0,
                 insert_count: 0,
                 update_count: 1,
                 unchanged_count: 0,
                 invalid_sheet_count: 0
               }
             } =
               BulkLoad.bulk_load(sheets, opts)

      assert %{events: events} =
               UploadEvents.get_job(opts.job_id)

      assert [
               %{
                 response: %{
                   "details" => %{"implementation_key" => ^impl_key},
                   "row_number" => 2,
                   "type" => "updated"
                 },
                 status: "INFO"
               }
             ] = events

      assert %{
               df_content: %{
                 "numeric_field" => %{"value" => ^numeric_field_value, "origin" => "user"}
               }
             } = Implementations.get_implementation(impl_id)
    end

    test "update implementation with empty template column", %{
      opts: opts,
      domain: domain,
      template: template
    } do
      %{
        id: impl_id,
        implementation_key: impl_key,
        result_type: result_type,
        goal: goal,
        minimum: minimum
      } =
        insert(:implementation,
          implementation_key: "impl_key",
          df_name: template.name,
          df_content: %{
            "string_field" => %{"value" => "string_value", "origin" => "file"},
            "numeric_field" => %{"value" => 8, "origin" => "user"}
          },
          template: template,
          domain_id: domain.id
        )

      sheets = %{
        template.name =>
          {[
             "english_implementation_key",
             "english_implementation_template",
             "english_result_type",
             "english_goal",
             "english_minimum",
             "domain_external_id",
             "english_string_field",
             "english_numeric_field"
           ],
           [
             [
               impl_key,
               template.name,
               result_type,
               goal,
               minimum,
               domain.external_id,
               "string_value_change",
               ""
             ]
           ]}
      }

      assert {
               :ok,
               %{
                 error_count: 0,
                 insert_count: 0,
                 update_count: 1,
                 unchanged_count: 0,
                 invalid_sheet_count: 0
               }
             } =
               BulkLoad.bulk_load(sheets, opts)

      assert %{events: events} =
               UploadEvents.get_job(opts.job_id)

      assert [
               %{
                 response: %{
                   "details" => %{"implementation_key" => ^impl_key},
                   "row_number" => 2,
                   "type" => "updated"
                 },
                 status: "INFO"
               }
             ] = events

      assert %{
               df_content: %{
                 "numeric_field" => %{"value" => nil, "origin" => "file"}
               }
             } = Implementations.get_implementation(impl_id)
    end

    test "no need for update", %{opts: opts, domain: domain} do
      sheets = %{
        "Sheet1" =>
          {[
             "english_implementation_key",
             "english_implementation_template",
             "english_result_type",
             "english_goal",
             "english_minimum",
             "domain_external_id"
           ],
           [
             [
               "existing_impl",
               "impl_template",
               "translated_percentage",
               30,
               12,
               domain.external_id
             ]
           ]}
      }

      assert {:ok,
              %{
                error_count: 0,
                insert_count: 0,
                update_count: 0,
                unchanged_count: 1,
                invalid_sheet_count: 0
              }} =
               BulkLoad.bulk_load(sheets, opts)

      assert %{events: events} =
               UploadEvents.get_job(opts.job_id)

      assert [
               %{
                 response: %{
                   "details" => %{"implementation_key" => "existing_impl"},
                   "row_number" => 2,
                   "sheet" => "Sheet1",
                   "type" => "unchanged"
                 },
                 status: "INFO"
               }
             ] = events
    end

    test "update existing implementation", %{opts: opts, domain: domain} do
      sheets = %{
        "Sheet1" =>
          {[
             "english_implementation_key",
             "english_implementation_template",
             "english_result_type",
             "english_goal",
             "english_minimum",
             "domain_external_id",
             "english_executable",
             "english_records",
             "english_string_field"
           ],
           [
             [
               "existing_impl",
               "impl_template",
               "translated_percentage",
               75,
               50,
               domain.external_id,
               "executable",
               "records",
               "string_value"
             ]
           ]}
      }

      assert {:ok,
              %{
                error_count: 0,
                insert_count: 0,
                update_count: 1,
                unchanged_count: 0
              }} =
               BulkLoad.bulk_load(sheets, opts)

      assert %{
               latest_status: "INFO",
               latest_event_response: %{
                 "type" => "updated",
                 "details" => %{
                   "changes" => %{
                     "df_content" => %{
                       "string_field" => %{"origin" => "file", "value" => "string_value"}
                     },
                     "goal" => 75.0,
                     "minimum" => 50.0
                   },
                   "implementation_key" => "existing_impl"
                 },
                 "row_number" => 2,
                 "sheet" => "Sheet1"
               }
             } = UploadEvents.get_job(opts.job_id)
    end

    test "invalid update existing implementation", %{opts: opts, domain: domain} do
      sheets = %{
        "Sheet1" =>
          {[
             "english_implementation_key",
             "english_implementation_template",
             "english_result_type",
             "english_goal",
             "english_minimum",
             "domain_external_id",
             "english_executable",
             "english_records",
             "english_string_field"
           ],
           [
             [
               "existing_impl",
               "impl_template",
               "translated_percentage",
               50,
               75,
               domain.external_id,
               "executable",
               "records",
               "string_value"
             ]
           ]}
      }

      assert {:ok,
              %{
                error_count: 1,
                insert_count: 0,
                update_count: 0,
                unchanged_count: 0,
                invalid_sheet_count: 0
              }} =
               BulkLoad.bulk_load(sheets, opts)

      assert %{
               latest_status: "ERROR",
               latest_event_response: %{
                 "details" => [["goal", ["must.be.greater.than.or.equal.to.minimum", []]]],
                 "type" => "implementation_creation_error"
               }
             } =
               UploadEvents.get_job(opts.job_id)
    end

    test "error missing required header", %{opts: opts} do
      sheets = %{
        "Sheet1" =>
          {[
             "english_result_type",
             "english_goal",
             "english_minimum"
           ], [["translated_percentage", 75, 50]]}
      }

      assert {:ok,
              %{
                error_count: 0,
                insert_count: 0,
                update_count: 0,
                unchanged_count: 0,
                invalid_sheet_count: 1
              }} =
               BulkLoad.bulk_load(sheets, opts)

      assert %{
               latest_status: "ERROR",
               latest_event_response: %{
                 "details" => %{
                   "missing_headers" => [
                     "domain_external_id",
                     "english_implementation_key",
                     "english_implementation_template"
                   ]
                 },
                 "sheet" => "Sheet1",
                 "type" => "missing_required_headers"
               }
             } =
               UploadEvents.get_job(opts.job_id)
    end

    test "error template not found", %{opts: opts, domain: domain} do
      sheets = %{
        "Sheet1" =>
          {[
             "english_implementation_key",
             "english_implementation_template",
             "english_result_type",
             "english_goal",
             "english_minimum",
             "domain_external_id"
           ],
           [["impl_key", "invalid_template", "translated_percentage", 75, 50, domain.external_id]]}
      }

      assert {:ok,
              %{
                error_count: 1,
                insert_count: 0,
                update_count: 0,
                unchanged_count: 0,
                invalid_sheet_count: 0
              }} =
               BulkLoad.bulk_load(sheets, opts)

      assert %{events: events} =
               UploadEvents.get_job(opts.job_id)

      assert [
               %{
                 response: %{
                   "details" => %{"template_name" => "invalid_template"},
                   "row_number" => 2,
                   "sheet" => "Sheet1",
                   "type" => "invalid_template_name"
                 },
                 status: "ERROR"
               }
             ] = events
    end

    test "error domain not found", %{opts: opts} do
      sheets = %{
        "Sheet1" =>
          {[
             "english_implementation_key",
             "english_implementation_template",
             "english_result_type",
             "english_goal",
             "english_minimum",
             "domain_external_id"
           ],
           [["impl_key", "impl_template", "translated_percentage", 75, 50, "foo_domain_ext_id"]]}
      }

      assert {:ok,
              %{
                error_count: 1,
                insert_count: 0,
                update_count: 0,
                unchanged_count: 0,
                invalid_sheet_count: 0
              }} =
               BulkLoad.bulk_load(sheets, opts)

      assert %{events: events} =
               UploadEvents.get_job(opts.job_id)

      assert [
               %{
                 response: %{
                   "details" => %{"domain_external_id" => "foo_domain_ext_id"},
                   "row_number" => 2,
                   "sheet" => "Sheet1",
                   "type" => "invalid_domain_external_id"
                 },
                 status: "ERROR"
               }
             ] = events
    end

    test "error rule does not exist", %{opts: opts, domain: domain} do
      sheets = %{
        "Sheet1" =>
          {[
             "english_implementation_key",
             "english_implementation_template",
             "english_result_type",
             "english_goal",
             "english_minimum",
             "domain_external_id",
             "english_rule",
             "english_executable",
             "english_records",
             "english_string_field"
           ],
           [
             [
               "impl_key",
               "impl_template",
               "translated_percentage",
               75,
               50,
               domain.external_id,
               "rule",
               "executable",
               "records",
               "string_value"
             ]
           ]}
      }

      assert {:ok, %{error_count: 1, unchanged_count: 0, insert_count: 0, update_count: 0}} =
               BulkLoad.bulk_load(sheets, opts)

      assert %{
               latest_status: "ERROR",
               latest_event_response: %{
                 "row_number" => 2,
                 "sheet" => "Sheet1",
                 "type" => "invalid_associated_rule",
                 "details" => %{"rule_name" => "rule"}
               }
             } =
               UploadEvents.get_job(opts.job_id)
    end

    test "error invalid result goal", %{opts: opts, domain: domain} do
      sheets = %{
        "Sheet1" =>
          {[
             "english_implementation_key",
             "english_implementation_template",
             "english_result_type",
             "english_goal",
             "english_minimum",
             "domain_external_id",
             "english_executable",
             "english_records",
             "english_string_field"
           ],
           [
             [
               "impl_key",
               "impl_template",
               "translated_percentage",
               50,
               90,
               domain.external_id,
               "executable",
               "records",
               "string_value"
             ]
           ]}
      }

      assert {:ok,
              %{
                error_count: 1,
                insert_count: 0,
                update_count: 0
              }} =
               BulkLoad.bulk_load(sheets, opts)

      assert %{
               latest_status: "ERROR",
               latest_event_response: %{
                 "details" => [["goal", ["must.be.greater.than.or.equal.to.minimum", []]]],
                 "type" => "implementation_creation_error"
               }
             } =
               UploadEvents.get_job(opts.job_id)
    end

    test "handles different errors individually for sheet and row", %{opts: opts, domain: domain} do
      sheets = %{
        "invalid_sheet" =>
          {[
             "english_result_type",
             "english_goal",
             "english_minimum"
           ], [["translated_percentage", 75, 50]]},
        "valid_sheet" =>
          {[
             "english_implementation_key",
             "english_implementation_template",
             "english_result_type",
             "english_goal",
             "english_minimum",
             "domain_external_id",
             "english_rule"
           ],
           [
             [
               "impl_key_invalid_domain",
               "impl_template",
               "translated_percentage",
               75,
               50,
               "invalid_domain"
             ],
             [
               "impl_key_invalid_template",
               "invalid_template",
               "translated_percentage",
               75,
               50,
               domain.external_id
             ],
             [
               "impl_key_invalid_rule",
               "impl_template",
               "translated_percentage",
               75,
               50,
               domain.external_id,
               "rule"
             ],
             [
               "impl_key_invalid_content",
               "impl_template",
               "translated_percentage",
               50,
               90,
               domain.external_id
             ],
             [
               "valid_impl_key",
               "impl_template",
               "translated_percentage",
               75,
               50,
               domain.external_id
             ]
           ]}
      }

      assert {:ok,
              %{
                invalid_sheet_count: 1,
                error_count: 4,
                insert_count: 1,
                update_count: 0,
                unchanged_count: 0
              }} =
               BulkLoad.bulk_load(sheets, opts)

      assert %{events: events} =
               UploadEvents.get_job(opts.job_id)

      assert [
               %{
                 response: %{
                   "details" => %{
                     "missing_headers" => [
                       "domain_external_id",
                       "english_implementation_key",
                       "english_implementation_template"
                     ]
                   },
                   "sheet" => "invalid_sheet",
                   "type" => "missing_required_headers"
                 },
                 status: "ERROR"
               },
               %{
                 response: %{
                   "details" => %{"domain_external_id" => "invalid_domain"},
                   "row_number" => 2,
                   "sheet" => "valid_sheet",
                   "type" => "invalid_domain_external_id"
                 },
                 status: "ERROR"
               },
               %{
                 response: %{
                   "details" => %{"template_name" => "invalid_template"},
                   "row_number" => 3,
                   "sheet" => "valid_sheet",
                   "type" => "invalid_template_name"
                 },
                 status: "ERROR"
               },
               %{
                 response: %{
                   "details" => %{"rule_name" => "rule"},
                   "row_number" => 4,
                   "sheet" => "valid_sheet",
                   "type" => "invalid_associated_rule"
                 },
                 status: "ERROR"
               },
               %{
                 response: %{
                   "details" => [["goal", ["must.be.greater.than.or.equal.to.minimum", []]]],
                   "row_number" => 5,
                   "sheet" => "valid_sheet",
                   "type" => "implementation_creation_error"
                 },
                 status: "ERROR"
               },
               %{
                 response: %{
                   "details" => %{"implementation_key" => "valid_impl_key"},
                   "row_number" => 6,
                   "sheet" => "valid_sheet",
                   "type" => "created"
                 },
                 status: "INFO"
               }
             ] = events
    end
  end
end
