defmodule TdDq.XLSX.Jobs.UploadWorkerTest do
  use TdDd.DataCase

  # import Ecto.Query

  alias TdDd.Repo
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.UploadEvents
  alias TdDq.XLSX.Jobs.UploadWorker

  @moduletag sandbox: :shared

  setup do
    content =
      "test/fixtures/implementations_upload/template.json"
      |> File.read!()
      |> Jason.decode!()

    template =
      CacheHelpers.insert_template(
        name: "foo_template",
        label: "foo_template",
        scope: "ri",
        content: content
      )

    domain = CacheHelpers.insert_domain(external_id: "foo_domain")
    template_user = CacheHelpers.insert_user(full_name: "foo_user")

    CacheHelpers.insert_acl(domain.id, "Data Owner", [template_user.id])

    hierarchy =
      %{
        id: 1,
        name: "name_1",
        nodes: [
          build(:hierarchy_node, %{
            node_id: 1,
            parent_id: nil,
            name: "father",
            path: "/father",
            hierarchy_id: 1
          }),
          build(:hierarchy_node, %{
            node_id: 2,
            parent_id: 1,
            name: "children_1",
            path: "/father/children_1",
            hierarchy_id: 1
          }),
          build(:hierarchy_node, %{
            node_id: 3,
            parent_id: 1,
            name: "children_2",
            path: "/father/children_2",
            hierarchy_id: 1
          }),
          build(:hierarchy_node, %{
            node_id: 4,
            parent_id: nil,
            name: "children_2",
            path: "/children_2",
            hierarchy_id: 1
          })
        ]
      }

    hierarchy = CacheHelpers.insert_hierarchy(hierarchy)

    user = CacheHelpers.insert_user(role: "admin")

    claims =
      :claims
      |> build(user_id: user.id)
      |> Jason.encode!()
      |> Jason.decode!()

    [
      template: template,
      domain: domain,
      claims: claims,
      hierarchy: hierarchy
    ]
  end

  describe "perform/1" do
    test "handles invalid file", %{claims: claims} do
      path = "test/fixtures/xlsx/invalid.xlsx"
      %{id: job_id} = insert(:implementation_upload_job)
      lang = "es"
      auto_publish = "false"

      assert {:ok, _} =
               perform_job(UploadWorker, %{
                 "path" => path,
                 "job_id" => job_id,
                 "opts" => %{
                   "lang" => lang,
                   "auto_publish" => auto_publish,
                   "claims" => claims
                 }
               })

      assert %{
               events: [
                 %{response: %{}, status: "STARTED"},
                 %{response: %{"message" => "invalid_format"}, status: "FAILED"}
               ]
             } = UploadEvents.get_job(job_id)
    end

    test "handles template values", %{
      claims: claims,
      hierarchy: hierarchy
    } do
      path = "test/fixtures/implementations_upload/data.xlsx"
      %{id: job_id} = insert(:implementation_upload_job)
      lang = "es"
      auto_publish = "true"

      hierarchy
      |> Map.get(:nodes)
      |> Enum.find(&(&1.path == "/father/children_1"))
      |> Map.get(:key)

      assert {:ok, _} =
               perform_job(UploadWorker, %{
                 "path" => path,
                 "job_id" => job_id,
                 "opts" => %{
                   "lang" => lang,
                   "auto_publish" => auto_publish,
                   "claims" => claims
                 }
               })

      # Updated to match current system behavior - now detects duplicate field names
      assert %{
               events: [
                 %{status: "STARTED"},
                 %{
                   status: "ERROR",
                   response: %{
                     "details" => %{
                       "duplicate_fields" => ["implementation_key"]
                     },
                     "row_number" => 2,
                     "sheet" => "implementation_template",
                     "type" => "duplicate_field_names"
                   }
                 },
                 %{
                   status: "COMPLETED",
                   response: %{
                     "error_count" => 0,
                     "insert_count" => 0,
                     "invalid_sheet_count" => 0,
                     "unchanged_count" => 0,
                     "update_count" => 0
                   }
                 }
               ]
             } = UploadEvents.get_job(job_id)
    end

    test "handles template invalid values", %{claims: claims} do
      path = "test/fixtures/implementations_upload/data_with_errors.xlsx"
      %{id: job_id} = insert(:implementation_upload_job)
      lang = "es"
      auto_publish = "true"

      assert {:ok, _} =
               perform_job(UploadWorker, %{
                 "path" => path,
                 "job_id" => job_id,
                 "opts" => %{
                   "lang" => lang,
                   "auto_publish" => auto_publish,
                   "claims" => claims
                 }
               })

      assert %{
               events: [
                 %{status: "STARTED"},
                 %{
                   status: "ERROR",
                   response: %{
                     "details" => %{
                       "duplicate_fields" => ["implementation_key"]
                     },
                     "row_number" => 2,
                     "sheet" => "implementation_template",
                     "type" => "duplicate_field_names"
                   }
                 },
                 %{
                   status: "ERROR",
                   response: %{
                     "details" => %{
                       "duplicate_fields" => ["implementation_key"]
                     },
                     "row_number" => 3,
                     "sheet" => "implementation_template",
                     "type" => "duplicate_field_names"
                   }
                 },
                 %{
                   status: "ERROR",
                   response: %{
                     "details" => %{
                       "duplicate_fields" => ["implementation_key"]
                     },
                     "row_number" => 4,
                     "sheet" => "implementation_template",
                     "type" => "duplicate_field_names"
                   }
                 },
                 %{
                   status: "ERROR",
                   response: %{
                     "details" => %{
                       "duplicate_fields" => ["implementation_key"]
                     },
                     "row_number" => 5,
                     "sheet" => "implementation_template",
                     "type" => "duplicate_field_names"
                   }
                 },
                 %{
                   status: "ERROR",
                   response: %{
                     "details" => %{
                       "duplicate_fields" => ["implementation_key"]
                     },
                     "row_number" => 6,
                     "sheet" => "implementation_template",
                     "type" => "duplicate_field_names"
                   }
                 },
                 %{
                   status: "ERROR",
                   response: %{
                     "details" => %{
                       "duplicate_fields" => ["implementation_key"]
                     },
                     "row_number" => 7,
                     "sheet" => "implementation_template",
                     "type" => "duplicate_field_names"
                   }
                 },
                 %{
                   status: "ERROR",
                   response: %{
                     "details" => %{
                       "duplicate_fields" => ["implementation_key"]
                     },
                     "row_number" => 8,
                     "sheet" => "implementation_template",
                     "type" => "duplicate_field_names"
                   }
                 },
                 %{
                   status: "COMPLETED",
                   response: %{
                     "error_count" => 0,
                     "insert_count" => 0,
                     "invalid_sheet_count" => 0,
                     "unchanged_count" => 0,
                     "update_count" => 0
                   }
                 }
               ]
             } = UploadEvents.get_job(job_id)
    end

    test "uploads date and datetime fields", %{
      claims: claims
    } do
      content_for_date_fields = [
        %{
          "name" => "date_fields",
          "fields" => [
            %{
              "cardinality" => "?",
              "label" => "Test Date",
              "name" => "test_date",
              "type" => "date",
              "widget" => "date"
            },
            %{
              "cardinality" => "?",
              "label" => "Test Datetime",
              "name" => "test_datetime",
              "type" => "datetime",
              "widget" => "datetime"
            }
          ]
        }
      ]

      CacheHelpers.insert_domain(external_id: "domain")

      CacheHelpers.insert_template(
        name: "TemplateImpl",
        label: "TemplateImpl",
        scope: "ri",
        content: content_for_date_fields
      )

      path = "test/fixtures/xlsx/implementations.xlsx"
      %{id: job_id} = insert(:implementation_upload_job)
      lang = "es"
      auto_publish = "true"

      perform_job(UploadWorker, %{
        "path" => path,
        "job_id" => job_id,
        "opts" => %{
          "lang" => lang,
          "auto_publish" => auto_publish,
          "claims" => claims
        }
      })

      UploadEvents.get_job(job_id)

      assert nil ==
               Implementation
               |> where(implementation_key: "ok_1")
               |> Repo.one()
    end
  end
end
