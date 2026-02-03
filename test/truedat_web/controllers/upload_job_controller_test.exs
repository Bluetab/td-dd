defmodule TruedatWeb.UploadJobControllerTest do
  use TruedatWeb.ConnCase

  alias Truedat.Audit.UploadJobs

  describe "index" do
    @tag authentication: [user_name: "user1"]
    test "lists upload jobs for the authenticated user", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: job_id_1} = insert(:upload_job, user_id: user_id, scope: "implementations")
      %{id: job_id_2} = insert(:upload_job, user_id: user_id, scope: "notes")
      insert(:upload_job, user_id: user_id + 1, scope: "implementations")

      assert %{"data" => data} =
               conn
               |> get(Routes.upload_job_path(conn, :index))
               |> json_response(:ok)

      assert length(data) == 2
      job_ids = Enum.map(data, & &1["id"])
      assert job_id_1 in job_ids
      assert job_id_2 in job_ids
    end

    @tag authentication: [user_name: "user1"]
    test "filters upload jobs by scope when scope param is provided", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: implementations_job_id} =
        insert(:upload_job, user_id: user_id, scope: "implementations")

      insert(:upload_job, user_id: user_id, scope: "notes")

      assert %{"data" => [job]} =
               conn
               |> get(Routes.upload_job_path(conn, :index), %{scope: "implementations"})
               |> json_response(:ok)

      assert job["id"] == implementations_job_id
      assert job["scope"] == "implementations"
    end

    @tag authentication: [user_name: "user1"]
    test "returns empty list when user has no upload jobs", %{conn: conn} do
      assert %{"data" => []} =
               conn
               |> get(Routes.upload_job_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "user1"]
    test "returns jobs with latest status and event information", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: job_id} = insert(:upload_job, user_id: user_id)
      {:ok, _} = UploadJobs.create_pending(job_id)
      {:ok, _} = UploadJobs.create_started(job_id)
      {:ok, _} = UploadJobs.create_completed(job_id, %{message: "Success"})

      assert %{"data" => [job]} =
               conn
               |> get(Routes.upload_job_path(conn, :index))
               |> json_response(:ok)

      assert job["id"] == job_id
      assert job["latest_status"] == "COMPLETED"
      assert job["latest_event_response"] == %{"message" => "Success"}
      refute is_nil(job["latest_event_at"])
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.upload_job_path(conn, :index))
      assert response(conn, :unauthorized)
    end
  end

  describe "show" do
    @tag authentication: [user_name: "user1"]
    test "shows a specific upload job belonging to the user", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: job_id, filename: filename, hash: hash, scope: scope} =
        insert(:upload_job, user_id: user_id, scope: "implementations")

      assert %{"data" => job} =
               conn
               |> get(Routes.upload_job_path(conn, :show, job_id))
               |> json_response(:ok)

      assert job["id"] == job_id
      assert job["user_id"] == user_id
      assert job["filename"] == filename
      assert job["hash"] == hash
      assert job["scope"] == scope
    end

    @tag authentication: [user_name: "user1"]
    test "shows job with events when they exist", %{conn: conn, claims: %{user_id: user_id}} do
      %{id: job_id} = insert(:upload_job, user_id: user_id)
      {:ok, %{id: event_id_1}} = UploadJobs.create_pending(job_id)
      {:ok, %{id: event_id_2}} = UploadJobs.create_started(job_id)
      {:ok, %{id: event_id_3}} = UploadJobs.create_completed(job_id, %{message: "Done"})

      assert %{"data" => job} =
               conn
               |> get(Routes.upload_job_path(conn, :show, job_id))
               |> json_response(:ok)

      assert job["id"] == job_id
      assert job["latest_status"] == "COMPLETED"

      assert %{"events" => events} = job
      assert length(events) == 3

      event_ids = Enum.map(events, & &1["id"])
      assert event_id_1 in event_ids
      assert event_id_2 in event_ids
      assert event_id_3 in event_ids

      [first_event | _] = events
      assert first_event["status"] == "PENDING"
    end

    @tag authentication: [user_name: "user1"]
    test "returns 404 when job belongs to another user", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: job_id} = insert(:upload_job, user_id: user_id + 1)

      assert conn
             |> get(Routes.upload_job_path(conn, :show, job_id))
             |> response(:not_found)
    end

    @tag authentication: [user_name: "user1"]
    test "returns 404 when job does not exist", %{conn: conn} do
      assert conn
             |> get(Routes.upload_job_path(conn, :show, 99_999))
             |> response(:not_found)
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, Routes.upload_job_path(conn, :show, 1))
      assert response(conn, :unauthorized)
    end
  end
end
