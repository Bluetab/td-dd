defmodule TrueDat.Audit.UploadJobsTest do
  use TdDd.DataCase

  alias Truedat.Audit.UploadJobs

  describe "create_job/1" do
    test "with valid data creates a job" do
      assert {:ok, %Truedat.Audit.UploadJobs.UploadJob{}} =
               UploadJobs.create_job(%{
                 user_id: 1,
                 hash: "hash",
                 filename: "filename",
                 scope: "implementations"
               })
    end

    test "with invalid data returns error" do
      assert {:error, %Ecto.Changeset{}} =
               UploadJobs.create_job(%{user_id: nil, hash: nil, filename: nil})
    end
  end

  describe "list_jobs/0" do
    test "returns a list of jobs" do
      %{
        id: job_id,
        user_id: user_id,
        hash: hash,
        filename: filename,
        scope: scope
      } = insert(:upload_job)

      assert [job] = UploadJobs.list_jobs()

      assert %{
               id: ^job_id,
               user_id: ^user_id,
               hash: ^hash,
               filename: ^filename,
               scope: ^scope
             } = job

      Enum.map(1..2, fn _ -> insert(:upload_job) end)

      assert jobs = UploadJobs.list_jobs()

      assert Enum.count(jobs) == 3
    end

    test "filters by user_id when provided" do
      user_id_1 = 100
      user_id_2 = 200

      %{id: job_id_1} = insert(:upload_job, user_id: user_id_1)
      %{id: job_id_2} = insert(:upload_job, user_id: user_id_1)
      insert(:upload_job, user_id: user_id_2)

      assert jobs = UploadJobs.list_jobs(user_id: user_id_1)

      assert Enum.count(jobs) == 2
      job_ids = Enum.map(jobs, & &1.id)
      assert job_id_1 in job_ids
      assert job_id_2 in job_ids
    end

    test "filters by scope when provided" do
      %{id: impl_job_id} = insert(:upload_job, scope: "implementations")
      insert(:upload_job, scope: "notes")

      assert [job] = UploadJobs.list_jobs(scope: "implementations")

      assert job.id == impl_job_id
      assert job.scope == "implementations"
    end

    test "filters by both user_id and scope when both provided" do
      user_id = 100

      %{id: target_job_id} = insert(:upload_job, user_id: user_id, scope: "implementations")
      insert(:upload_job, user_id: user_id, scope: "notes")
      insert(:upload_job, user_id: user_id + 1, scope: "implementations")

      assert [job] = UploadJobs.list_jobs(user_id: user_id, scope: "implementations")

      assert job.id == target_job_id
      assert job.user_id == user_id
      assert job.scope == "implementations"
    end

    test "returns jobs with latest event information" do
      %{id: job_id} = insert(:upload_job)
      {:ok, _} = UploadJobs.create_pending(job_id)
      {:ok, _} = UploadJobs.create_started(job_id)
      {:ok, _} = UploadJobs.create_completed(job_id, %{message: "Success"})

      assert [job] = UploadJobs.list_jobs()

      assert job.id == job_id
      assert job.latest_status == "COMPLETED"
      assert job.latest_event_response == %{"message" => "Success"}
      refute is_nil(job.latest_event_at)
    end
  end

  describe "get_job/1" do
    test "returns a job" do
      %{
        id: job_id,
        user_id: user_id,
        hash: hash,
        filename: filename,
        scope: scope
      } = insert(:upload_job)

      assert job = UploadJobs.get_job(job_id)

      assert %{
               id: ^job_id,
               user_id: ^user_id,
               hash: ^hash,
               filename: ^filename,
               scope: ^scope
             } = job
    end
  end

  describe "create_pending/1" do
    test "with valid data creates a job" do
      %{id: job_id} = insert(:upload_job)
      assert {:ok, %{job_id: ^job_id, status: "PENDING"}} = UploadJobs.create_pending(job_id)
    end

    test "with invalid data returns error" do
      assert {:error, %Ecto.Changeset{}} = UploadJobs.create_pending(nil)
    end
  end

  describe "create_error/2" do
    test "with valid data creates a job" do
      %{id: job_id} = insert(:upload_job)

      assert {:ok, %{job_id: ^job_id, status: "ERROR"}} =
               UploadJobs.create_error(job_id, %{error: "error"})
    end

    test "with invalid data returns error" do
      assert {:error, %Ecto.Changeset{}} = UploadJobs.create_error(nil, %{error: "error"})
    end
  end

  describe "create_info/2" do
    test "with valid data creates a job" do
      %{id: job_id} = insert(:upload_job)

      assert {:ok, %{job_id: ^job_id, status: "INFO"}} =
               UploadJobs.create_info(job_id, %{info: "info"})
    end

    test "with invalid data returns error" do
      assert {:error, %Ecto.Changeset{}} = UploadJobs.create_info(nil, %{info: "info"})
    end
  end

  describe "create_failed/2" do
    test "with valid data creates a job" do
      %{id: job_id} = insert(:upload_job)

      assert {:ok, %{job_id: ^job_id, status: "FAILED"}} =
               UploadJobs.create_failed(job_id, %{failed: "failed"})
    end

    test "with invalid data returns error" do
      assert {:error, %Ecto.Changeset{}} = UploadJobs.create_failed(nil, %{failed: "failed"})
    end
  end

  describe "create_started/1" do
    test "with valid data creates a job" do
      %{id: job_id} = insert(:upload_job)

      assert {:ok, %{job_id: ^job_id, status: "STARTED"}} =
               UploadJobs.create_started(job_id)
    end

    test "with invalid data returns error" do
      assert {:error, %Ecto.Changeset{}} = UploadJobs.create_started(nil)
    end
  end

  describe "create_completed/2" do
    test "with valid data creates a job" do
      %{id: job_id} = insert(:upload_job)

      assert {:ok, %{job_id: ^job_id, status: "COMPLETED"}} =
               UploadJobs.create_completed(job_id, %{completed: "completed"})
    end

    test "with invalid data returns error" do
      assert {:error, %Ecto.Changeset{}} =
               UploadJobs.create_completed(nil, %{completed: "completed"})
    end
  end
end
