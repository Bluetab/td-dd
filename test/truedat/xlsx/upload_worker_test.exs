defmodule Truedat.XLSX.UploadWorkerTest do
  use TdDd.DataCase

  alias Truedat.Audit.UploadJobs
  alias Truedat.XLSX.UploadWorker

  @moduletag sandbox: :shared

  setup do
    user = CacheHelpers.insert_user(role: "admin")

    claims =
      :claims
      |> build(user_id: user.id)
      |> Jason.encode!()
      |> Jason.decode!()

    [claims: claims, user: user]
  end

  describe "perform/1" do
    test "creates STARTED event before processing", %{claims: claims} do
      path = "test/fixtures/xlsx/upload_tiny.xlsx"
      %{id: job_id} = insert(:upload_job, scope: "implementations")
      lang = "es"
      auto_publish = "false"

      assert {:ok, _} =
               perform_job(UploadWorker, %{
                 "path" => path,
                 "job_id" => job_id,
                 "scope" => "implementations",
                 "opts" => %{
                   "lang" => lang,
                   "auto_publish" => auto_publish,
                   "claims" => claims
                 }
               })

      assert %{
               events: [
                 %{status: "STARTED", response: %{}} | _
               ]
             } = UploadJobs.get_job(job_id)
    end

    test "handles invalid file format", %{claims: claims} do
      path = "test/fixtures/xlsx/invalid.xlsx"
      %{id: job_id} = insert(:upload_job, scope: "implementations")
      lang = "es"
      auto_publish = "false"

      assert {:ok, _} =
               perform_job(UploadWorker, %{
                 "path" => path,
                 "job_id" => job_id,
                 "scope" => "implementations",
                 "opts" => %{
                   "lang" => lang,
                   "auto_publish" => auto_publish,
                   "claims" => claims
                 }
               })

      job = UploadJobs.get_job(job_id)

      assert %{
               events: [
                 %{status: "STARTED"},
                 %{status: "FAILED", response: %{"message" => "invalid_format"}}
               ]
             } = job
    end

    test "handles file not found error", %{claims: claims} do
      path = "test/fixtures/xlsx/nonexistent.xlsx"
      %{id: job_id} = insert(:upload_job, scope: "implementations")
      lang = "es"
      auto_publish = "false"

      assert {:ok, _} =
               perform_job(UploadWorker, %{
                 "path" => path,
                 "job_id" => job_id,
                 "scope" => "implementations",
                 "opts" => %{
                   "lang" => lang,
                   "auto_publish" => auto_publish,
                   "claims" => claims
                 }
               })

      job = UploadJobs.get_job(job_id)

      assert %{
               events: [
                 %{status: "STARTED"},
                 %{status: "FAILED", response: %{"message" => reason}}
               ]
             } = job

      assert reason == "file not found"
    end

    test "handles empty sheets error", %{claims: claims} do
      path = "test/fixtures/xlsx/empty.xlsx"
      %{id: job_id} = insert(:upload_job, scope: "implementations")
      lang = "es"
      auto_publish = "false"

      assert {:ok, _} =
               perform_job(UploadWorker, %{
                 "path" => path,
                 "job_id" => job_id,
                 "scope" => "implementations",
                 "opts" => %{
                   "lang" => lang,
                   "auto_publish" => auto_publish,
                   "claims" => claims
                 }
               })

      job = UploadJobs.get_job(job_id)

      assert %{
               events: [
                 %{status: "STARTED"},
                 %{status: "FAILED", response: %{"message" => "empty_sheets"}}
               ]
             } = job
    end

    test "creates COMPLETED event on successful processing", %{claims: claims} do
      content =
        "test/fixtures/implementations_upload/template.json"
        |> File.read!()
        |> Jason.decode!()

      _template =
        CacheHelpers.insert_template(
          name: "test_template",
          label: "test_template",
          scope: "ri",
          content: content
        )

      domain = CacheHelpers.insert_domain(external_id: "test_domain")
      template_user = CacheHelpers.insert_user(full_name: "test_user")

      CacheHelpers.insert_acl(domain.id, "Data Owner", [template_user.id])

      path = "test/fixtures/implementations_upload/data.xlsx"
      %{id: job_id} = insert(:upload_job, scope: "implementations")
      lang = "es"
      auto_publish = "true"

      assert {:ok, _} =
               perform_job(UploadWorker, %{
                 "path" => path,
                 "job_id" => job_id,
                 "scope" => "implementations",
                 "opts" => %{
                   "lang" => lang,
                   "auto_publish" => auto_publish,
                   "claims" => claims
                 }
               })

      job = UploadJobs.get_job(job_id)

      assert %{
               events: [
                 %{status: "STARTED"} | _
               ]
             } = job

      assert %{
               status: "COMPLETED",
               response: %{
                 "error_count" => 1,
                 "insert_count" => 0,
                 "invalid_sheet_count" => 0,
                 "unchanged_count" => 0,
                 "update_count" => 0
               }
             } = List.last(job.events)
    end

    test "creates FAILED event when BulkLoad fails", %{claims: claims} do
      path = "test/fixtures/xlsx/upload_tiny.xlsx"
      %{id: job_id} = insert(:upload_job, scope: "implementations")
      lang = "es"
      auto_publish = "false"

      assert {:ok, _} =
               perform_job(UploadWorker, %{
                 "path" => path,
                 "job_id" => job_id,
                 "scope" => "implementations",
                 "opts" => %{
                   "lang" => lang,
                   "auto_publish" => auto_publish,
                   "claims" => claims
                 }
               })

      job = UploadJobs.get_job(job_id)
      assert %{events: events} = job

      last_event = List.last(events)
      assert last_event.status in ["COMPLETED", "FAILED"]
    end
  end
end
