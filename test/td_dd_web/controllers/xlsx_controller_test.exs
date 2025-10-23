defmodule TdDdWeb.DataStructures.XLSXControllerTest do
  use Oban.Testing, repo: TdDd.Repo, prefix: Application.get_env(:td_dd, Oban)[:prefix]
  use TdDdWeb.ConnCase

  import Mox

  alias TdCore.Utils.FileHash
  alias TdDd.DataStructures.FileBulkUpdateEvent
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Repo
  alias TdDd.Search.StructureEnricher
  alias TdDd.XLSX.Jobs.UploadWorker
  alias XlsxReader

  @moduletag sandbox: :shared
  @file_upload_dir Application.compile_env(:td_dd, :file_upload_dir)

  setup_all do
    start_supervised({Task.Supervisor, name: TdDd.TaskSupervisor})
    on_exit(fn -> File.rm_rf(@file_upload_dir) end)
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
        assert query[:bool][:must] == %{term: %{"data_structure_id" => "#{structure.id}"}}
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
        assert query[:bool][:must] == %{
                 multi_match: %{
                   type: "bool_prefix",
                   fields: ["data_structure_id", "parent_id"],
                   lenient: true,
                   operator: "OR",
                   query: "#{parent_structure.id}"
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
        assert query[:bool][:must] == %{term: %{"data_structure_id" => "#{structure.id}"}}
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
  end

  describe "upload" do
    @tag authentication: [role: "admin"]
    test "creates async job for upload processing for published notes", %{
      conn: conn,
      claims: claims
    } do
      file = "test/fixtures/xlsx/upload.xlsx"

      opts = %{
        "auto_publish" => false,
        "lang" => "en",
        "user_id" => claims.user_id,
        "claims" => %{
          "user_id" => claims.user_id,
          "user_name" => claims.user_name,
          "jti" => claims.jti
        }
      }

      hash = FileHash.hash("test/fixtures/xlsx/upload.xlsx", :md5)

      assert conn
             |> post(Routes.xlsx_path(conn, :upload),
               structures: upload(file),
               note_type: :published
             )
             |> response(:accepted)

      assert_enqueued worker: UploadWorker,
                      args: %{hash: hash, opts: opts},
                      queue: :xlsx_upload_queue

      assert [%Oban.Job{id: job_id}] = all_enqueued()

      assert [event] = Repo.all(FileBulkUpdateEvent)

      assert Map.take(event, [:user_id, :status, :hash, :filename, :task_reference]) == %{
               user_id: claims.user_id,
               status: "PENDING",
               hash: hash,
               filename: "upload.xlsx",
               task_reference: "oban:#{job_id}"
             }

      assert_enqueued(
        worker: UploadWorker,
        args: %{hash: hash, opts: opts},
        queue: :xlsx_upload_queue
      )
    end

    @tag authentication: [role: "admin"]
    test "creates async job for upload processing for non-published notes", %{
      conn: conn,
      claims: claims
    } do
      file = "test/fixtures/xlsx/upload.xlsx"

      opts = %{
        "auto_publish" => false,
        "lang" => "en",
        "user_id" => claims.user_id,
        "claims" => %{
          "user_id" => claims.user_id,
          "user_name" => claims.user_name,
          "jti" => claims.jti
        }
      }

      hash = FileHash.hash("test/fixtures/xlsx/upload.xlsx", :md5)

      assert conn
             |> post(Routes.xlsx_path(conn, :upload),
               structures: upload(file),
               note_type: :non_published
             )
             |> response(:accepted)

      assert_enqueued(
        worker: UploadWorker,
        args: %{hash: hash, opts: opts},
        queue: :xlsx_upload_queue
      )

      assert [%Oban.Job{id: job_id}] = all_enqueued()

      assert [event] = Repo.all(FileBulkUpdateEvent)

      assert Map.take(event, [:user_id, :status, :hash, :filename, :task_reference]) == %{
               user_id: claims.user_id,
               status: "PENDING",
               hash: hash,
               filename: "upload.xlsx",
               task_reference: "oban:#{job_id}"
             }

      assert_enqueued(
        worker: UploadWorker,
        args: %{hash: hash, opts: opts},
        queue: :xlsx_upload_queue
      )
    end
  end
end
