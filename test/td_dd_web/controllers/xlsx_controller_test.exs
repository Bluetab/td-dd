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

  describe "download_notes" do
    @tag authentication: [role: "admin"]
    test "returns not found when structure does not exist", %{conn: conn} do
      assert conn
             |> post("/api/data_structures/99999/notes/xlsx/download", %{
               statuses: ["published"]
             })
             |> response(:not_found)
    end

    @tag authentication: [role: "admin"]
    test "downloads xlsx with notes for a single structure", %{conn: conn} do
      df_content = %{"string" => %{"value" => "foo", "origin" => "user"}}
      domain = CacheHelpers.insert_domain()

      structure = insert(:data_structure, domain_ids: [domain.id])

      dsv =
        insert(:data_structure_version,
          data_structure: structure
        )

      insert(:structure_note,
        data_structure: structure,
        df_content: df_content,
        status: :published,
        version: 1
      )

      %{id: template_id} =
        CacheHelpers.insert_template(%{
          name: dsv.type,
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{"name" => "string", "type" => "string", "label" => "Label foo"}
              ]
            }
          ]
        })

      insert(:data_structure_type, name: dsv.type, template_id: template_id)

      assert %{resp_body: body} =
               post(conn, "/api/data_structures/#{structure.id}/notes/xlsx/download", %{
                 statuses: ["published"],
                 lang: "en"
               })

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)
      assert sheets = XlsxReader.sheet_names(workbook)
      assert [sheet_name] = sheets

      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, sheet_name)

      assert headers == ["external_id", "name", "status", "version", "updated_at", "string"]

      assert [[external_id, name, status, version, _updated_at, string_value]] = content
      assert external_id == structure.external_id
      assert name == dsv.name
      assert status == "published"
      assert version == 1
      assert string_value == "foo"
    end

    @tag authentication: [role: "admin"]
    test "downloads xlsx with notes for structure and children", %{conn: conn} do
      df_content_parent = %{"string" => %{"value" => "parent_value", "origin" => "user"}}
      df_content_child = %{"string" => %{"value" => "child_value", "origin" => "user"}}

      domain = CacheHelpers.insert_domain()

      parent_structure = insert(:data_structure, domain_ids: [domain.id])

      parent_dsv =
        insert(:data_structure_version,
          data_structure: parent_structure,
          type: "Table"
        )

      insert(:structure_note,
        data_structure: parent_structure,
        df_content: df_content_parent,
        status: :published,
        version: 1
      )

      child_structure = insert(:data_structure, domain_ids: [domain.id])

      child_dsv =
        insert(:data_structure_version,
          data_structure: child_structure,
          type: "Table"
        )

      # Create parent-child relationship
      insert(:data_structure_relation,
        parent_id: parent_dsv.id,
        child_id: child_dsv.id,
        relation_type_id: RelationTypes.default_id!()
      )

      insert(:structure_note,
        data_structure: child_structure,
        df_content: df_content_child,
        status: :published,
        version: 1
      )

      %{id: template_id} =
        CacheHelpers.insert_template(%{
          name: "Table",
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{"name" => "string", "type" => "string", "label" => "Label foo"}
              ]
            }
          ]
        })

      insert(:data_structure_type, name: "Table", template_id: template_id)

      assert %{resp_body: body} =
               post(conn, "/api/data_structures/#{parent_structure.id}/notes/xlsx/download", %{
                 statuses: ["published"],
                 include_children: true,
                 lang: "en"
               })

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)
      assert sheets = XlsxReader.sheet_names(workbook)
      assert length(sheets) == 2

      [parent_sheet_name, child_sheet_name] = sheets
      assert parent_sheet_name == parent_dsv.name
      assert child_sheet_name == child_dsv.name

      # Verify parent sheet
      assert {:ok, [parent_headers | parent_content]} =
               XlsxReader.sheet(workbook, parent_sheet_name)

      assert parent_headers == [
               "external_id",
               "name",
               "status",
               "version",
               "updated_at",
               "string"
             ]

      assert [[_ext_id, _name, _status, _version, _updated_at, string_value]] = parent_content
      assert string_value == "parent_value"

      assert {:ok, [child_headers | child_content]} = XlsxReader.sheet(workbook, child_dsv.name)

      assert child_headers == [
               "external_id",
               "name",
               "status",
               "version",
               "updated_at",
               "string"
             ]

      assert [[_ext_id, _name, _status, _version, _updated_at, string_value]] = child_content
      assert string_value == "child_value"
    end

    @tag authentication: [role: "admin"]
    test "downloads xlsx with multiple note statuses", %{conn: conn} do
      df_content_published = %{"string" => %{"value" => "published_value", "origin" => "user"}}
      df_content_draft = %{"string" => %{"value" => "draft_value", "origin" => "user"}}

      domain = CacheHelpers.insert_domain()
      structure = insert(:data_structure, domain_ids: [domain.id])

      dsv = insert(:data_structure_version, data_structure: structure)

      insert(:structure_note,
        data_structure: structure,
        df_content: df_content_published,
        status: :published,
        version: 1
      )

      insert(:structure_note,
        data_structure: structure,
        df_content: df_content_draft,
        status: :draft,
        version: 2
      )

      %{id: template_id} =
        CacheHelpers.insert_template(%{
          name: dsv.type,
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{"name" => "string", "type" => "string", "label" => "Label foo"}
              ]
            }
          ]
        })

      insert(:data_structure_type, name: dsv.type, template_id: template_id)

      assert %{resp_body: body} =
               post(conn, "/api/data_structures/#{structure.id}/notes/xlsx/download", %{
                 statuses: ["published", "draft"],
                 lang: "en"
               })

      assert {:ok, workbook} = XlsxReader.open(body, source: :binary)
      assert sheets = XlsxReader.sheet_names(workbook)
      assert [sheet_name] = sheets

      assert {:ok, [_headers | content]} = XlsxReader.sheet(workbook, sheet_name)

      assert length(content) == 2

      statuses =
        Enum.map(content, fn [_ext_id, _name, status, _version, _updated_at, _str] -> status end)

      assert "published" in statuses
      assert "draft" in statuses
    end

    @tag authentication: [role: "user"]
    test "returns forbidden when user does not have permission", %{conn: conn} do
      domain = CacheHelpers.insert_domain()
      structure = insert(:data_structure, domain_ids: [domain.id])
      _dsv = insert(:data_structure_version, data_structure: structure)

      assert conn
             |> post("/api/data_structures/#{structure.id}/notes/xlsx/download", %{
               statuses: ["published"]
             })
             |> response(:forbidden)
    end
  end
end
