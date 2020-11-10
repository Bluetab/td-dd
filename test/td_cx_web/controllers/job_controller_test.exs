defmodule TdCxWeb.JobControllerTest do
  use TdCxWeb.ConnCase

  alias TdCx.Search.IndexWorker

  def fixture(:job) do
    insert(:job)
  end

  setup_all do
    start_supervised(IndexWorker)
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    setup [:create_job]

    @tag :admin_authenticated
    test "lists jobs of a source", %{conn: conn, job: job} do
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

    @tag :admin_authenticated
    test "search all", %{conn: conn, job: job} do
      source = Map.get(job, :source, %{})
      conn = post(conn, Routes.job_path(conn, :search), %{})

      assert json_response(conn, 200)["data"] == [
               %{
                 "external_id" => job.external_id,
                 "source" => %{"external_id" => source.external_id, "type" => source.type}
               }
             ]
    end
  end

  describe "create job" do
    @tag :admin_authenticated
    test "creates job for a source", %{conn: conn} do
      %{external_id: source_external_id} = insert(:source)

      assert %{"data" => data} =
               conn
               |> post(Routes.source_job_path(conn, :create, source_external_id))
               |> json_response(:created)

      assert %{"external_id" => external_id} = data
      assert not is_nil(external_id)
    end

    @tag :admin_authenticated
    test "renders errors when source does not exist", %{conn: conn} do
      conn = post(conn, Routes.source_job_path(conn, :create, "invented external_id"))
      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "show" do
    setup [:create_job]

    @tag :admin_authenticated
    test "show created job", %{conn: conn, job: job} do
      %{external_id: external_id, source: source} = job
      %{external_id: source_external_id, type: source_type} = source

      conn = get(conn, Routes.job_path(conn, :show, job.external_id))

      assert %{"data" => data} =
               conn
               |> get(Routes.job_path(conn, :show, job.external_id))
               |> json_response(:ok)

      assert %{"external_id" => ^external_id, "_embedded" => embedded} = data
      assert %{"source" => source} = embedded
      assert %{"external_id" => ^source_external_id, "type" => ^source_type} = source
    end
  end

  defp create_job(_) do
    job = fixture(:job)
    {:ok, job: job}
  end
end
