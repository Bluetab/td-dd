defmodule TdCxWeb.JobControllerTest do
  use TdCxWeb.ConnCase

  def fixture(:job) do
    insert(:job)
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    setup [:create_job]

    @tag :admin_authenticated
    test "lists jobs of a source", %{conn: conn, job: job} do
      source = Map.get(job, :source, %{})
      conn = get(conn, Routes.source_job_path(conn, :source_jobs, source.external_id))
      assert json_response(conn, 200)["data"] == [%{"external_id" => job.external_id, "source_id" => source.id}]
    end
  end

  describe "create job" do
    @tag :admin_authenticated
    test "creates job for a source", %{conn: conn} do
      source = insert(:source)
      conn = post(conn, Routes.source_job_path(conn, :create_job, source.external_id))
      assert %{"external_id" => external_id} = json_response(conn, 201)["data"]
      assert not is_nil(external_id)

      conn = get(conn, Routes.source_job_path(conn, :source_jobs, source.external_id))

      assert json_response(conn, 200)["data"] == [%{"external_id" => external_id, "source_id" => source.id}]
    end

    @tag :admin_authenticated
    test "renders errors when source does not exist", %{conn: conn} do
      conn = post(conn, Routes.source_job_path(conn, :create_job, "invented external_id"))
      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  defp create_job(_) do
    job = fixture(:job)
    {:ok, job: job}
  end
end
