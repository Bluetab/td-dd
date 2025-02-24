defmodule TdDd.Xlsx.Jobs.UploadWorkerTest do
  use TdDd.DataCase

  alias TdCore.Search.IndexWorkerMock
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.FileBulkUpdateEvent
  alias TdDd.Search.StructureEnricher
  alias TdDd.XLSX.Jobs.UploadWorker

  @moduletag sandbox: :shared

  @content [
    %{
      "name" => "group",
      "fields" => [
        %{
          "cardinality" => "?",
          "label" => "Text",
          "name" => "text",
          "type" => "string",
          "widget" => "string"
        }
      ]
    }
  ]

  setup_all do
    start_supervised({Task.Supervisor, name: TdDd.TaskSupervisor})
    :ok
  end

  describe "TdDd.XLSX.Jobs.UploadWorker.perform/1" do
    setup %{test_pid: test_pid} do
      IndexWorkerMock.clear()
      start_supervised!(StructureEnricher)

      subfolder =
        test_pid
        |> :erlang.pid_to_list()
        |> List.delete_at(0)
        |> List.delete_at(-1)
        |> to_string()

      parent_dir = Path.join(["test", subfolder])
      File.mkdir_p!(parent_dir)

      path = "test/fixtures/xlsx/upload_tiny.xlsx"
      file_name = "upload_tiny.xlsx"
      tmp_path = Path.join([parent_dir, file_name])
      File.cp_r!(path, tmp_path)

      on_exit(fn ->
        File.rm_rf!(parent_dir)
        IndexWorkerMock.clear()
      end)

      %{id: id, name: type1} =
        CacheHelpers.insert_template(content: @content, type: "type_1", name: "type_1")

      domain = CacheHelpers.insert_domain()

      structure_type = insert(:data_structure_type, name: type1, template_id: id)

      structures =
        Enum.map(1..3, fn id ->
          insert(:data_structure_version,
            structure_type: structure_type,
            type: "type_1",
            data_structure:
              build(:data_structure, external_id: "ex_id#{id}", domain_ids: [domain.id])
          ).data_structure
        end)

      user_ids =
        Enum.map(["Role", "Role 1", "Role 2"], fn full_name ->
          CacheHelpers.insert_user(full_name: full_name).id
        end)

      %{domain_ids: [domain_id]} = List.first(structures)
      CacheHelpers.insert_acl(domain_id, "Data Owner", user_ids)

      [
        structures: structures,
        domain: domain,
        tmp_path: tmp_path,
        file_name: file_name,
        parent_dir: parent_dir
      ]
    end

    test "uploads file", %{
      structures: structures,
      domain: %{id: domain_id},
      tmp_path: tmp_path,
      file_name: file_name
    } do
      hash = Base.encode16(tmp_path)
      claims = %{user_id: user_id} = build(:claims, role: "user")

      CacheHelpers.put_session_permissions(claims, %{
        create_structure_note: [domain_id],
        publish_structure_note_from_draft: [domain_id],
        edit_structure_note: [domain_id],
        view_data_structure: [domain_id]
      })

      opts = %{
        "auto_publish" => true,
        "user_id" => user_id,
        "claims" => %{
          "user_id" => claims.user_id,
          "user_name" => claims.user_name,
          "jti" => claims.jti,
          "role" => claims.role
        }
      }

      assert :ok =
               perform_job(
                 UploadWorker,
                 %{
                   path: tmp_path,
                   file_name: file_name,
                   hash: hash,
                   opts: opts
                 }
               )

      refute File.exists?(tmp_path)

      assert structures =
               [_ | _] =
               Enum.map(structures, fn %{id: id} ->
                 DataStructure |> Repo.get(id) |> Repo.preload(:published_note)
               end)

      assert structure =
               Enum.find(structures, fn %{external_id: external_id} -> external_id == "ex_id1" end)

      assert structure.published_note.df_content == %{
               "text" => %{"origin" => "file", "value" => "text"}
             }

      assert structure =
               Enum.find(structures, fn %{external_id: external_id} -> external_id == "ex_id2" end)

      assert structure.published_note.df_content == %{
               "text" => %{"origin" => "file", "value" => "text2"}
             }

      assert structure =
               Enum.find(structures, fn %{external_id: external_id} -> external_id == "ex_id3" end)

      assert structure.published_note.df_content == %{
               "text" => %{"origin" => "file", "value" => ""}
             }

      assert events = Repo.all(FileBulkUpdateEvent)
      assert Enum.count(events) == 2

      assert started_event = Enum.find(events, fn %{status: status} -> status == "STARTED" end)

      assert Map.take(started_event, [:user_id, :status, :hash, :filename]) == %{
               user_id: user_id,
               status: "STARTED",
               hash: hash,
               filename: "upload_tiny.xlsx"
             }

      assert started_event.task_reference

      assert completed_event =
               Enum.find(events, fn %{status: status} -> status == "COMPLETED" end)

      assert %{
               user_id: ^user_id,
               status: "COMPLETED",
               hash: ^hash,
               filename: "upload_tiny.xlsx",
               response: %{"errors" => [], "ids" => ids},
               task_reference: task_refence
             } =
               Map.take(completed_event, [
                 :user_id,
                 :status,
                 :hash,
                 :filename,
                 :response,
                 :task_reference
               ])

      assert task_refence
      assert Enum.all?(structures, fn %{id: id} -> id in ids end)
    end

    test "cancels job when user has not permissions", %{
      tmp_path: tmp_path,
      file_name: file_name
    } do
      claims = %{user_id: user_id} = build(:claims, role: "user")
      hash = "hash"

      opts = %{
        "auto_publish" => true,
        "user_id" => user_id,
        "claims" => %{
          "user_id" => claims.user_id,
          "user_name" => claims.user_name,
          "jti" => claims.jti,
          "role" => claims.role
        }
      }

      assert {:cancel, :forbidden} =
               perform_job(UploadWorker, %{
                 path: tmp_path,
                 file_name: file_name,
                 hash: hash,
                 opts: opts
               })

      refute File.exists?(tmp_path)
    end

    test "handles error response", %{parent_dir: parent_dir} do
      path = "test/fixtures/xlsx/upload_empty_external_id.xlsx"
      file_name = "upload_empty_external_id.xlsx"
      tmp_path = Path.join([parent_dir, file_name])
      hash = "hash"
      File.cp_r!(path, tmp_path)

      on_exit(fn -> File.rm_rf!(parent_dir) end)

      claims = %{user_id: user_id} = build(:claims, role: "user")

      opts = %{
        "auto_publish" => true,
        "user_id" => user_id,
        "claims" => %{
          "user_id" => claims.user_id,
          "user_name" => claims.user_name,
          "jti" => claims.jti,
          "role" => claims.role
        }
      }

      {:error, %{message: :external_id_not_found}} =
        perform_job(UploadWorker, %{
          path: tmp_path,
          file_name: file_name,
          hash: hash,
          opts: opts
        })

      assert File.exists?(tmp_path)

      {:error, %{message: :external_id_not_found}} =
        perform_job(
          UploadWorker,
          %{
            path: tmp_path,
            file_name: file_name,
            hash: hash,
            opts: opts
          },
          attempt: 5
        )

      refute File.exists?(tmp_path)
    end
  end
end
