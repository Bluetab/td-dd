defmodule TdCxWeb.EventControllerTest do
  use TdCxWeb.ConnCase

  alias TdCx.Search.IndexWorker

  @valid_attrs %{"date" => DateTime.utc_now(), "type" => "init", "message" => "Message"}

  def fixture(:event) do
    insert(:event)
  end

  setup_all do
    start_supervised(IndexWorker)
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    setup [:create_event]

    @tag :admin_authenticated
    test "lists events of a job", %{conn: conn, event: event} do
      job = Map.get(event, :job, %{})
      conn = get(conn, Routes.job_event_path(conn, :job_events, job.external_id))
      events = json_response(conn, 200)["data"]

      assert length(events) == 1
      assert Enum.any?(events, &(&1["id"] == event.id))
    end
  end

  describe "create event" do
    @tag :admin_authenticated
    test "creates event for a job", %{conn: conn} do
      job = insert(:job)

      conn =
        post(conn, Routes.job_event_path(conn, :create_event, job.external_id),
          event: @valid_attrs
        )

      event = json_response(conn, 201)["data"]

      assert not is_nil(event["id"])
      assert event["type"] == @valid_attrs["type"]
      assert event["message"] == @valid_attrs["message"]
    end

    @tag :admin_authenticated
    test "renders errors when job does not exist", %{conn: conn} do
      conn =
        post(conn, Routes.job_event_path(conn, :create_event, Ecto.UUID.generate()), event: %{})

      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  defp create_event(_) do
    event = fixture(:event)
    {:ok, event: event}
  end
end
