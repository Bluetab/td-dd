defmodule TdCxWeb.JobControllerTest do
  use TdCxWeb.ConnCase

  alias TdCx.Search.IndexWorker

  setup_all do
    start_supervised(IndexWorker)
    :ok
  end

  describe "GET /api/sources/:id/jobs" do
    setup :create_job

    @tag authentication: [role: "admin"]
    test "admin can view jobs of a source", %{conn: conn, job: job} do
      %{source: source, external_id: external_id} = job
      %{external_id: source_external_id, type: source_type} = source

      assert %{"data" => data} =
               conn
               |> get(Routes.source_job_path(conn, :index, source_external_id))
               |> json_response(:ok)

      assert [
               %{
                 "external_id" => ^external_id,
                 "source" => %{"external_id" => ^source_external_id, "type" => ^source_type}
               }
             ] = data
    end

    @tag authentication: [role: "admin"]
    test "search all", %{conn: conn, job: job} do
      source = Map.get(job, :source, %{})

      assert %{"data" => data} =
               conn
               |> post(Routes.job_path(conn, :search), %{})
               |> json_response(:ok)

      assert data == [
               %{
                 "external_id" => job.external_id,
                 "source" => %{"external_id" => source.external_id, "type" => source.type},
                 "type" => job.type
               }
             ]
    end
  end

  describe "POST /api/sources/:id/jobs" do
    @tag authentication: [role: "user"]
    test "user can create a job for a source", %{conn: conn, claims: %{user_id: user_id}} do
      %{external_id: source_external_id} = insert(:source)
      create_acl_entry(user_id, "domain_id", [:profile_structures])

      assert %{"data" => data} =
               conn
               |> post(Routes.source_job_path(conn, :create, source_external_id))
               |> json_response(:created)

      assert %{"external_id" => external_id} = data
      refute is_nil(external_id)
    end

    @tag authentication: [role: "admin"]
    test "admin can create a job for a source", %{conn: conn} do
      %{external_id: source_external_id} = insert(:source)

      assert %{"data" => data} =
               conn
               |> post(Routes.source_job_path(conn, :create, source_external_id))
               |> json_response(:created)

      assert %{"external_id" => external_id} = data
      refute is_nil(external_id)
    end

    @tag authentication: [role: "service"]
    test "service account can create a job for a source", %{conn: conn} do
      %{external_id: source_external_id} = insert(:source)

      assert %{"data" => data} =
               conn
               |> post(Routes.source_job_path(conn, :create, source_external_id))
               |> json_response(:created)

      assert %{"external_id" => external_id} = data
      refute is_nil(external_id)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when source does not exist", %{conn: conn} do
      conn = post(conn, Routes.source_job_path(conn, :create, "invented external_id"))
      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "GET /api/jobs/:id" do
    setup :create_job

    @tag authentication: [role: "admin"]
    test "admin can view created job", %{conn: conn, job: job} do
      %{external_id: external_id, source: source} = job
      %{external_id: source_external_id, type: source_type} = source

      assert %{"data" => data} =
               conn
               |> get(Routes.job_path(conn, :show, job.external_id))
               |> json_response(:ok)

      assert %{"external_id" => ^external_id, "_embedded" => embedded} = data
      assert %{"source" => source} = embedded
      assert %{"external_id" => ^source_external_id, "type" => ^source_type} = source
    end

    @tag authentication: [role: "service"]
    test "service account can view created job", %{conn: conn, job: job} do
      %{external_id: external_id} = job

      assert %{"data" => data} =
               conn
               |> get(Routes.job_path(conn, :show, job.external_id))
               |> json_response(:ok)

      assert %{"external_id" => ^external_id} = data
    end

    @tag authentication: [role: "user"]
    test "user account with profile_structures permission can view created job", %{
      conn: conn,
      job: job,
      claims: %{user_id: user_id}
    } do
      %{external_id: external_id} = job

      create_acl_entry(user_id, "domain_id", [:profile_structures])

      assert %{"data" => data} =
               conn
               |> get(Routes.job_path(conn, :show, job.external_id))
               |> json_response(:ok)

      assert %{"external_id" => ^external_id} = data
    end
  end

  defp create_job(_) do
    [job: insert(:job)]
  end
end
