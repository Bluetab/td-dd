defmodule TdDdWeb.DataStructures.XLSXControllerTest do
  use Oban.Testing, repo: TdDd.Repo, prefix: Application.get_env(:td_dd, Oban)[:prefix]
  use TdDdWeb.ConnCase

  import Mox

  alias TdCore.Utils.FileHash
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Repo
  alias TdDd.Search.StructureEnricher
  alias Truedat.Audit.UploadEvents.UploadEvent
  alias Truedat.Audit.UploadJobs.UploadJob
  alias XlsxReader

  @moduletag sandbox: :shared
  @file_upload_dir Application.compile_env(:td_dd, :file_upload_dir)
  @temp_dir "test/tmp"

  setup_all do
    File.mkdir_p!(@temp_dir)
    start_supervised({Task.Supervisor, name: TdDd.TaskSupervisor})

    on_exit(fn ->
      File.rm_rf(@file_upload_dir)
      File.rm_rf(@temp_dir)
    end)

    :ok
  end

  setup do
    start_supervised!(StructureEnricher)
    :ok
  end

  describe "download" do
    @tag authentication: [role: "admin"]
    test "returns no content on empty response from elastic search", %{conn: conn} do
      expect(ElasticsearchMock, :request, fn _, :post, "/structures/_search", _, _opts ->
        SearchHelpers.scroll_response([])
      end)

      assert conn
             |> post(Routes.xlsx_path(conn, :download, %{}))
             |> response(:no_content)
    end

    @tag authentication: [role: "admin"]
    test "downloads xlsx content for published notes using scroll to search", %{conn: conn} do
      df_content = %{"string" => %{"value" => "foo", "origin" => "user"}}

      domain = CacheHelpers.insert_domain()

      structure =
        insert(:data_structure,
          domain_ids: [domain.id],
          published_note:
            build(:structure_note,
              df_content: df_content,
              status: :published,
              data_structure: nil
            )
        )

      dsv =
        insert(:data_structure_version,
          data_structure: structure
        )

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: dsv.type,
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "string",
                  "type" => "string",
                  "label" => "Label foo"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: dsv.type, template_id: id)

      assert :ok = StructureEnricher.refresh()

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", _, opts ->
        assert opts == [params: %{"scroll" => "1m"}]
        SearchHelpers.scroll_response([dsv])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      assert %{resp_body: body} =
               post(
                 conn,
                 Routes.xlsx_path(conn, :download, %{
                   download_type: "editable",
                   note_type: "published"
                 })
               )

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)
      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, dsv.type)

      assert headers == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path",
               "string"
             ]

      assert content == [
               [
                 structure.external_id,
                 dsv.name,
                 dsv.name,
                 "",
                 "",
                 domain.name,
                 dsv.type,
                 dsv.data_structure.system.name,
                 "",
                 "foo"
               ]
             ]
    end

    @tag authentication: [role: "admin"]
    test "downloads xlsx content for draft notes using scroll to search", %{conn: conn} do
      df_content = %{"string" => %{"value" => "foo", "origin" => "user"}}

      domain = CacheHelpers.insert_domain()

      structure =
        insert(:data_structure,
          domain_ids: [domain.id],
          draft_note:
            build(:structure_note,
              df_content: df_content,
              status: :draft,
              data_structure: nil
            )
        )

      dsv =
        insert(:data_structure_version,
          data_structure: structure
        )

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: dsv.type,
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "string",
                  "type" => "string",
                  "label" => "Label foo"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: dsv.type, template_id: id)

      assert :ok = StructureEnricher.refresh()

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", _, opts ->
        assert opts == [params: %{"scroll" => "1m"}]
        SearchHelpers.scroll_response([dsv])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      assert %{resp_body: body} =
               post(
                 conn,
                 Routes.xlsx_path(conn, :download, %{
                   download_type: "editable",
                   note_type: "non_published"
                 })
               )

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)
      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, dsv.type)

      assert headers == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path",
               "string"
             ]

      assert content == [
               [
                 structure.external_id,
                 dsv.name,
                 dsv.name,
                 "",
                 "",
                 domain.name,
                 dsv.type,
                 dsv.data_structure.system.name,
                 "",
                 "foo"
               ]
             ]
    end

    @tag authentication: [role: "admin"]
    test "downloads xlsx content for pending-approval notes using scroll to search", %{conn: conn} do
      df_content = %{"string" => %{"value" => "foo", "origin" => "user"}}

      domain = CacheHelpers.insert_domain()

      structure =
        insert(:data_structure,
          domain_ids: [domain.id],
          pending_approval_note:
            build(:structure_note,
              df_content: df_content,
              status: :pending_approval,
              data_structure: nil
            )
        )

      dsv =
        insert(:data_structure_version,
          data_structure: structure
        )

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: dsv.type,
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "string",
                  "type" => "string",
                  "label" => "Label foo"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: dsv.type, template_id: id)

      assert :ok = StructureEnricher.refresh()

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", _, opts ->
        assert opts == [params: %{"scroll" => "1m"}]
        SearchHelpers.scroll_response([dsv])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      assert %{resp_body: body} =
               post(
                 conn,
                 Routes.xlsx_path(conn, :download, %{
                   download_type: "editable",
                   note_type: "non_published"
                 })
               )

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)
      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, dsv.type)

      assert headers == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path",
               "string"
             ]

      assert content == [
               [
                 structure.external_id,
                 dsv.name,
                 dsv.name,
                 "",
                 "",
                 domain.name,
                 dsv.type,
                 dsv.data_structure.system.name,
                 "",
                 "foo"
               ]
             ]
    end

    @tag authentication: [role: "admin"]
    test "downloads xlsx content for rejected notes using scroll to search", %{conn: conn} do
      df_content = %{"string" => %{"value" => "foo", "origin" => "user"}}

      domain = CacheHelpers.insert_domain()

      structure =
        insert(:data_structure,
          domain_ids: [domain.id],
          rejected_note:
            build(:structure_note,
              df_content: df_content,
              status: :rejected,
              data_structure: nil
            )
        )

      dsv =
        insert(:data_structure_version,
          data_structure: structure
        )

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: dsv.type,
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "string",
                  "type" => "string",
                  "label" => "Label foo"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: dsv.type, template_id: id)

      assert :ok = StructureEnricher.refresh()

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", _, opts ->
        assert opts == [params: %{"scroll" => "1m"}]
        SearchHelpers.scroll_response([dsv])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      assert %{resp_body: body} =
               post(
                 conn,
                 Routes.xlsx_path(conn, :download, %{
                   download_type: "editable",
                   note_type: "non_published"
                 })
               )

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)
      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, dsv.type)

      assert headers == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path",
               "string"
             ]

      assert content == [
               [
                 structure.external_id,
                 dsv.name,
                 dsv.name,
                 "",
                 "",
                 domain.name,
                 dsv.type,
                 dsv.data_structure.system.name,
                 "",
                 "foo"
               ]
             ]
    end

    @tag authentication: [role: "admin"]
    test "downloads xlsx with data_structure_id and include_children false", %{conn: conn} do
      df_content = %{"string" => %{"value" => "foo", "origin" => "user"}}

      domain = CacheHelpers.insert_domain()

      structure =
        insert(:data_structure,
          domain_ids: [domain.id],
          published_note:
            build(:structure_note,
              df_content: df_content,
              status: :published,
              data_structure: nil
            )
        )

      dsv =
        insert(:data_structure_version,
          data_structure: structure
        )

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: dsv.type,
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "string",
                  "type" => "string",
                  "label" => "Label foo"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: dsv.type, template_id: id)

      assert :ok = StructureEnricher.refresh()

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, opts ->
        assert query[:bool][:filter] == %{term: %{"data_structure_id" => "#{structure.id}"}}
        assert opts == [params: %{"scroll" => "1m"}]
        SearchHelpers.scroll_response([dsv])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      assert %{resp_body: body} =
               post(
                 conn,
                 Routes.xlsx_path(conn, :download, %{
                   data_structure_id: structure.id,
                   include_children: false,
                   download_type: "editable",
                   note_type: "published"
                 })
               )

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)
      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, dsv.type)

      assert headers == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path",
               "string"
             ]

      assert content == [
               [
                 structure.external_id,
                 dsv.name,
                 dsv.name,
                 "",
                 "",
                 domain.name,
                 dsv.type,
                 dsv.data_structure.system.name,
                 "",
                 "foo"
               ]
             ]
    end

    @tag authentication: [role: "admin"]
    test "downloads xlsx with data_structure_id and include_children true", %{conn: conn} do
      df_content = %{"string" => %{"value" => "foo", "origin" => "user"}}

      domain = CacheHelpers.insert_domain()

      parent_structure =
        insert(:data_structure,
          domain_ids: [domain.id],
          published_note:
            build(:structure_note,
              df_content: df_content,
              status: :published,
              data_structure: nil
            )
        )

      child_structure =
        insert(:data_structure,
          domain_ids: [domain.id],
          published_note:
            build(:structure_note,
              df_content: df_content,
              status: :published,
              data_structure: nil
            )
        )

      parent_dsv =
        insert(:data_structure_version,
          type: "Table",
          data_structure: parent_structure
        )

      child_dsv =
        insert(:data_structure_version,
          type: "Table",
          data_structure: child_structure
        )

      insert(:data_structure_relation,
        parent_id: parent_dsv.id,
        child_id: child_dsv.id,
        relation_type_id: RelationTypes.default_id!()
      )

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: parent_dsv.type,
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "string",
                  "type" => "string",
                  "label" => "Label foo"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: parent_dsv.type, template_id: id)

      assert :ok = StructureEnricher.refresh()

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, opts ->
        assert query == %{
                 bool: %{
                   filter: %{
                     bool: %{
                       should: [
                         %{term: %{"data_structure_id" => "#{parent_structure.id}"}},
                         %{term: %{"parent_id" => "#{parent_structure.id}"}}
                       ],
                       minimum_should_match: 1
                     }
                   },
                   must_not: %{exists: %{field: "deleted_at"}}
                 }
               }

        assert opts == [params: %{"scroll" => "1m"}]
        SearchHelpers.scroll_response([parent_dsv, child_dsv])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      assert %{resp_body: body} =
               post(
                 conn,
                 Routes.xlsx_path(conn, :download, %{
                   data_structure_id: parent_structure.id,
                   include_children: true,
                   download_type: "editable",
                   note_type: "published"
                 })
               )

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)
      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, parent_dsv.type)

      assert headers == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path",
               "string"
             ]

      assert length(content) == 2

      # Usando ^ para hacer pin en las variables ya definidas
      parent_external_id = parent_structure.external_id
      parent_name = parent_dsv.name
      parent_type = parent_dsv.type
      parent_system_name = parent_dsv.data_structure.system.name

      child_external_id = child_structure.external_id
      child_name = child_dsv.name
      child_type = child_dsv.type
      child_system_name = child_dsv.data_structure.system.name

      domain_name = domain.name

      assert [
               [
                 ^parent_external_id,
                 ^parent_name,
                 ^parent_name,
                 "",
                 "",
                 ^domain_name,
                 ^parent_type,
                 ^parent_system_name,
                 "",
                 "foo"
               ],
               [
                 ^child_external_id,
                 ^child_name,
                 ^child_name,
                 "",
                 "",
                 ^domain_name,
                 ^child_type,
                 ^child_system_name,
                 "",
                 "foo"
               ]
             ] = content
    end

    @tag authentication: [role: "admin"]
    test "downloads xlsx with data_structure_id only (default include_children false)", %{
      conn: conn
    } do
      df_content = %{"string" => %{"value" => "foo", "origin" => "user"}}

      domain = CacheHelpers.insert_domain()

      structure =
        insert(:data_structure,
          domain_ids: [domain.id],
          published_note:
            build(:structure_note,
              df_content: df_content,
              status: :published,
              data_structure: nil
            )
        )

      dsv =
        insert(:data_structure_version,
          data_structure: structure
        )

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: dsv.type,
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "string",
                  "type" => "string",
                  "label" => "Label foo"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: dsv.type, template_id: id)

      assert :ok = StructureEnricher.refresh()

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, opts ->
        assert query[:bool][:filter] == %{term: %{"data_structure_id" => "#{structure.id}"}}
        assert opts == [params: %{"scroll" => "1m"}]
        SearchHelpers.scroll_response([dsv])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      assert %{resp_body: body} =
               post(
                 conn,
                 Routes.xlsx_path(conn, :download, %{
                   data_structure_id: structure.id,
                   download_type: "editable",
                   note_type: "published"
                 })
               )

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)
      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, dsv.type)

      assert headers == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path",
               "string"
             ]

      assert content == [
               [
                 structure.external_id,
                 dsv.name,
                 dsv.name,
                 "",
                 "",
                 domain.name,
                 dsv.type,
                 dsv.data_structure.system.name,
                 "",
                 "foo"
               ]
             ]
    end

    @tag authentication: [role: "admin"]
    test "downloads xlsx with date and datetime fields", %{
      conn: conn
    } do
      df_content = %{
        "test_date" => %{"value" => "2025-12-31", "origin" => "user"},
        "test_datetime" => %{"value" => "2025-12-31 22:55:00", "origin" => "user"}
      }

      domain = CacheHelpers.insert_domain()

      structure =
        insert(:data_structure,
          domain_ids: [domain.id],
          published_note:
            build(:structure_note,
              df_content: df_content,
              status: :published,
              data_structure: nil
            )
        )

      dsv =
        insert(:data_structure_version,
          data_structure: structure
        )

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: dsv.type,
          scope: "dd",
          content: [
            %{
              "name" => "date_fields",
              "fields" => [
                %{
                  "name" => "test_date",
                  "type" => "date",
                  "label" => "Test Date"
                },
                %{
                  "name" => "test_datetime",
                  "type" => "datetime",
                  "label" => "Test Datetime"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: dsv.type, template_id: id)

      assert :ok = StructureEnricher.refresh()

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, opts ->
        assert query[:bool][:filter] == %{term: %{"data_structure_id" => "#{structure.id}"}}
        assert opts == [params: %{"scroll" => "1m"}]
        SearchHelpers.scroll_response([dsv])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      assert %{resp_body: body} =
               post(
                 conn,
                 Routes.xlsx_path(conn, :download, %{
                   data_structure_id: structure.id,
                   download_type: "editable",
                   note_type: "published"
                 })
               )

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)
      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, dsv.type)

      assert headers == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path",
               "test_date",
               "test_datetime"
             ]

      assert content == [
               [
                 structure.external_id,
                 dsv.name,
                 dsv.name,
                 "",
                 "",
                 domain.name,
                 dsv.type,
                 dsv.data_structure.system.name,
                 "",
                 46_022.0,
                 46_022.954861111111
               ]
             ]
    end
  end

  describe "upload" do
    @tag authentication: [role: "admin"]
    test "admin will queue upload job", %{conn: conn, claims: claims} do
      filename = "upload.xlsx"
      path = "#{@temp_dir}/#{filename}"
      job_path = "test/upload/#{filename}"

      File.cp!("test/fixtures/xlsx/#{filename}", path)

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
               structures: upload(path),
               lang: lang,
               auto_publish: auto_publish
             )
             |> response(:ok)

      assert [
               %Oban.Job{
                 state: "available",
                 queue: "xlsx_implementations_upload_queue",
                 worker: "Truedat.XLSX.UploadWorker",
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

    @tag authentication: [role: "user", permissions: ["create_structure_note"]]
    test "user with permission will queue upload job", %{conn: conn, claims: claims} do
      filename = "upload.xlsx"
      path = "#{@temp_dir}/#{filename}"
      job_path = "test/upload/#{filename}"
      File.cp!("test/fixtures/xlsx/#{filename}", path)
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
               structures: upload(path),
               lang: lang,
               auto_publish: auto_publish
             )
             |> response(:ok)

      assert [
               %Oban.Job{
                 state: "available",
                 queue: "xlsx_implementations_upload_queue",
                 worker: "Truedat.XLSX.UploadWorker",
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
    test "user without permission will have forbidden", %{conn: conn} do
      filename = "upload.xlsx"
      path = "#{@temp_dir}/#{filename}"
      File.cp!("test/fixtures/xlsx/#{filename}", path)

      lang = "en"
      auto_publish = "true"

      assert conn
             |> post(Routes.xlsx_path(conn, :upload),
               structures: upload(path),
               lang: lang,
               auto_publish: auto_publish
             )
             |> response(:forbidden)

      assert [] = all_enqueued()

      %Truedat.Audit.UploadEvents.UploadEvent{
        response: %{"message" => "forbidden"},
        status: "FAILED"
      } = Repo.one(UploadEvent)
    end

    for note_type <- [:published, :non_published] do
      @tag authentication: [role: "admin"]
      test "creates async job for upload processing for #{note_type} notes", %{
        conn: conn,
        claims: %{user_id: user_id, user_name: user_name, jti: jti}
      } do
        note_type = unquote(note_type)
        file_name = "upload.xlsx"
        file = "#{@temp_dir}/#{file_name}"
        File.cp!("test/fixtures/xlsx/#{file_name}", file)
        hash = FileHash.hash(file, :md5)

        assert conn
               |> post(Routes.xlsx_path(conn, :upload),
                 structures: upload(file),
                 auto_publish: false,
                 note_type: note_type
               )
               |> response(:ok)

        assert_enqueued worker: "Truedat.XLSX.UploadWorker",
                        args: %{
                          opts: %{
                            "auto_publish" => false,
                            "lang" => "en",
                            "claims" => %{
                              "user_id" => user_id,
                              "user_name" => user_name,
                              "jti" => jti
                            }
                          }
                        },
                        queue: "xlsx_implementations_upload_queue"

        assert [%Oban.Job{args: %{"job_id" => job_id}}] = all_enqueued()

        assert %{
                 user_id: ^user_id,
                 hash: ^hash,
                 filename: ^file_name,
                 scope: "notes",
                 latest_status: nil,
                 latest_event_at: nil,
                 latest_event_response: nil
               } = Repo.one(UploadJob, id: job_id)

        assert %{
                 job_id: ^job_id,
                 status: "PENDING"
               } = Repo.one(UploadEvent, job_id: job_id)
      end
    end
  end
end
