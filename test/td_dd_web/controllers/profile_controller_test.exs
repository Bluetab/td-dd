defmodule TdDdWeb.ProfileControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.DataStructures.Profiles
  alias TdDd.Loader.Worker
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuthService

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    start_supervised(Worker)
    start_supervised({Task.Supervisor, name: TdDd.TaskSupervisor})
    :ok
  end

  setup %{fixture: fixture} do
    profiling = %Plug.Upload{path: fixture <> "/profiles.csv"}
    {:ok, profiling: profiling}
  end

  describe "upload profiling" do
    @tag :admin_authenticated
    @tag fixture: "test/fixtures/profiling"
    test "uploads profiles for data structures", %{
      conn: conn,
      profiling: profiling
    } do
      sys1 = insert(:system, external_id: "SYS1", name: "SYS1")

      insert(:data_structure, external_id: "DS1", system_id: sys1.id)
      insert(:data_structure, external_id: "DS2", system_id: sys1.id)
      insert(:data_structure, external_id: "DS3", system_id: sys1.id)

      conn = post(conn, Routes.profile_path(conn, :upload), profiling: profiling)

      assert response(conn, 202) =~ ""

      # waits for loader to complete
      Worker.await(20_000)
      assert Enum.count(Profiles.list_profiles()) == 3
    end
  end
end
