defmodule TdDq.XLSX.Jobs.UploadWorkerTest do
  use TdDd.DataCase

  alias TdDq.Implementations
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
      domain: %{id: domain_id},
      hierarchy: hierarchy
    } do
      path = "test/fixtures/implementations_upload/data.xlsx"
      %{id: job_id} = insert(:implementation_upload_job)
      lang = "es"
      auto_publish = "true"

      hierarchy_key =
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

      assert %{
               events: [
                 %{status: "STARTED"},
                 %{
                   status: "INFO",
                   response: %{
                     "details" => %{
                       "implementation_key" => implementation_key
                     },
                     "type" => "created"
                   }
                 },
                 %{
                   status: "COMPLETED",
                   response: %{
                     "error_count" => 0,
                     "insert_count" => 1,
                     "invalid_sheet_count" => 0,
                     "unchanged_count" => 0,
                     "update_count" => 0
                   }
                 }
               ]
             } = UploadEvents.get_job(job_id)

      assert {:ok,
              %{
                implementation_key: ^implementation_key,
                implementation_type: "basic",
                domain_id: ^domain_id,
                df_name: "foo_template",
                df_content: %{
                  "Hierarchie2" => %{"origin" => "file", "value" => ^hierarchy_key},
                  "basic_list" => %{"origin" => "file", "value" => "1"},
                  "basic_switch" => %{"origin" => "file", "value" => "a"},
                  "default_dependency" => %{"origin" => "file", "value" => "1.1"},
                  "df_description" => %{
                    "origin" => "file",
                    "value" => %{
                      "document" => %{
                        "nodes" => [
                          %{
                            "nodes" => [
                              %{
                                "leaves" => [%{"text" => "enriched text"}],
                                "object" => "text"
                              }
                            ],
                            "object" => "block",
                            "type" => "paragraph"
                          }
                        ]
                      }
                    }
                  },
                  "empty test" => %{"origin" => "file", "value" => ""},
                  "group1" => %{"origin" => "file", "value" => "user:foo_user"},
                  "multiple_values" => %{"origin" => "file", "value" => ["v-1", "v-2"]},
                  "text_area" => %{"origin" => "file", "value" => "text area"},
                  "text_input" => %{"origin" => "file", "value" => "text input"},
                  "urls" => %{
                    "origin" => "file",
                    "value" => [%{"url_name" => "Truedat", "url_value" => "docs.truedat.io"}]
                  },
                  "user1" => %{"origin" => "file", "value" => "foo_user"}
                },
                goal: 20.0,
                minimum: 10.0,
                result_type: "percentage",
                status: :published
              }} = Implementations.get_published_implementation_by_key(implementation_key)
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
                     "details" => [["df_content", ["basic_list: is invalid", _]]]
                   }
                 },
                 %{
                   status: "ERROR",
                   response: %{
                     "details" => [["df_content", ["basic_switch: is invalid", _]]]
                   }
                 },
                 %{
                   status: "ERROR",
                   response: %{
                     "details" => [["df_content", ["multiple_values: has an invalid entry", _]]]
                   }
                 },
                 %{
                   status: "ERROR",
                   response: %{
                     "details" => [["df_content", ["user1: is invalid", _]]]
                   }
                 },
                 %{
                   status: "ERROR",
                   response: %{
                     "details" => [["df_content", ["text_input: can't be blank", _]]]
                   }
                 },
                 %{
                   status: "ERROR",
                   response: %{
                     "details" => [
                       ["df_content", ["invalid content", [["Hierarchie2", ["hierarchy"]]]]]
                     ]
                   }
                 },
                 %{status: "INFO"},
                 %{
                   status: "COMPLETED",
                   response: %{
                     "error_count" => 6,
                     "insert_count" => 1
                   }
                 }
               ]
             } = UploadEvents.get_job(job_id)
    end
  end
end
