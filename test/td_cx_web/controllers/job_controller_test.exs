defmodule TdCxWeb.JobControllerTest do
  use TdCxWeb.ConnCase

  import Mox

  setup_all do
    start_supervised!(TdCx.Search.IndexWorker)
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "GET /api/sources/:id/jobs" do
    setup :create_job

    @tag authentication: [role: "admin"]
    test "admin can view jobs of a source", %{conn: conn, job: job} do
      %{source: source, external_id: external_id} = job
      %{external_id: source_external_id, type: source_type} = source

      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/jobs/_search", %{from: 0, query: query, size: 10_000}, _ ->
          assert query == %{
                   bool: %{
                     filter: %{term: %{"source.external_id" => source_external_id}}
                   }
                 }

          SearchHelpers.hits_response([job])
      end)

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
    test "search all", %{
      conn: conn,
      job: %{external_id: external_id, source: source, type: type} = job
    } do
      ElasticsearchMock
      |> expect(:request, fn
        _, :post, "/jobs/_search", _, _ -> SearchHelpers.hits_response([job])
      end)

      assert %{"data" => data} =
               conn
               |> post(Routes.job_path(conn, :search), %{})
               |> json_response(:ok)

      assert data == [
               %{
                 "external_id" => external_id,
                 "source" => %{"external_id" => source.external_id, "type" => source.type},
                 "source_id" => source.id,
                 "status" => "PENDING",
                 "type" => type,
                 "start_date" => DateTime.to_iso8601(job.inserted_at),
                 "end_date" => DateTime.to_iso8601(job.updated_at)
               }
             ]
    end
  end

  describe "POST /api/sources/:id/jobs" do
    @tag authentication: [role: "user", permissions: [:profile_structures]]
    test "user can create a job for a source", %{conn: conn} do
      %{external_id: source_external_id} = insert(:source)

      SearchHelpers.expect_bulk_index("/jobs/_doc/_bulk")

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

      SearchHelpers.expect_bulk_index("/jobs/_doc/_bulk")

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

      SearchHelpers.expect_bulk_index("/jobs/_doc/_bulk")

      assert %{"data" => data} =
               conn
               |> post(Routes.source_job_path(conn, :create, source_external_id))
               |> json_response(:created)

      assert %{"external_id" => external_id} = data
      refute is_nil(external_id)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when source does not exist", %{conn: conn} do
      assert_error_sent :not_found, fn ->
        post(conn, Routes.source_job_path(conn, :create, "invented external_id"))
      end
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
    test "service account can view created job", %{conn: conn, job: %{external_id: external_id}} do
      assert %{"data" => data} =
               conn
               |> get(Routes.job_path(conn, :show, external_id))
               |> json_response(:ok)

      assert %{"external_id" => ^external_id} = data
    end

    @tag authentication: [role: "user", permissions: [:profile_structures]]
    test "user account with profile_structures permission can view created job", %{
      conn: conn,
      job: %{external_id: external_id}
    } do
      assert %{"data" => data} =
               conn
               |> get(Routes.job_path(conn, :show, external_id))
               |> json_response(:ok)

      assert %{"external_id" => ^external_id} = data
    end
  end

  defp create_job(_) do
    ts = DateTime.utc_now() |> DateTime.add(-10)
    [job: insert(:job, inserted_at: ts)]
  end
end
