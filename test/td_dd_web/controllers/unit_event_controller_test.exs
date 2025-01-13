defmodule TdDdWeb.UnitEventControllerTest do
  use TdDdWeb.ConnCase

  setup do
    events = Enum.map(1..5, fn id -> build(:unit_event, event: "Event #{id}") end)
    unit = insert(:unit, events: events)

    [unit: unit]
  end

  describe "Unit Event Controller" do
    @tag authentication: [role: "admin"]
    test "GET /api/units/:name/events returns the list of events", %{
      conn: conn,
      unit: unit
    } do
      assert %{"data" => events} =
               conn
               |> get(Routes.unit_event_path(conn, :index, unit.name))
               |> json_response(:ok)

      assert length(events) == 5
    end
  end

  describe "Unit Event Controller for non-admin users" do
    @tag authentication: [user_name: "non_admin_user"]
    test "GET /api/units/:name/events returns forbidden", %{
      conn: conn,
      unit: unit
    } do
      assert conn
             |> get(Routes.unit_event_path(conn, :index, unit.name))
             |> json_response(:forbidden)
    end
  end
end
