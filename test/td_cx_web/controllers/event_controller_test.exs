defmodule TdCxWeb.EventControllerTest do
  use TdCxWeb.ConnCase

  import Mox

  setup do
    start_supervised!(TdCx.Search.IndexWorker)
    start_supervised!(TdCx.Cache.SourcesLatestEvent)
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  setup :verify_on_exit!

  setup do
    %{job: job} = event = insert(:event)
    [job: job, event: event]
  end

  describe "GET /api/jobs/:id/events" do
    @tag authentication: [role: "admin"]
    test "admin can view events of a job", %{
      conn: conn,
      event: %{id: event_id},
      job: %{external_id: job_external_id}
    } do
      assert %{"data" => data} =
               conn
               |> get(Routes.job_event_path(conn, :index, job_external_id))
               |> json_response(:ok)

      assert [%{"id" => ^event_id}] = data
    end
  end

  describe "POST /api/jobs/:id/events" do
    setup :set_mox_from_context

    @tag authentication: [role: "admin"]
    test "admin can create event for a job", %{conn: conn, job: %{external_id: external_id}} do
      SearchHelpers.expect_bulk_index("/jobs/_doc/_bulk")

      %{"type" => type, "message" => message} = params = string_params_for(:event)

      assert %{"data" => event} =
               conn
               |> post(Routes.job_event_path(conn, :index, external_id), event: params)
               |> json_response(:created)

      assert %{"id" => _id, "type" => ^type, "message" => ^message} = event
    end

    @tag authentication: [role: "service"]
    test "service account can create event for a job", %{
      conn: conn,
      job: %{external_id: external_id}
    } do
      SearchHelpers.expect_bulk_index("/jobs/_doc/_bulk")

      %{"type" => type, "message" => message} = params = string_params_for(:event)

      assert %{"data" => event} =
               conn
               |> post(Routes.job_event_path(conn, :index, external_id), event: params)
               |> json_response(:created)

      assert %{"id" => _id, "type" => ^type, "message" => ^message} = event
    end

    @tag authentication: [role: "admin"]
    test "renders errors when job does not exist", %{conn: conn} do
      assert_error_sent :not_found, fn ->
        post(conn, Routes.job_event_path(conn, :index, Ecto.UUID.generate()), event: %{})
      end
    end
  end
end
