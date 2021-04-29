defmodule TdDdWeb.ProfileControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.DataStructures.Profiles
  alias TdDd.Loader.Worker

  setup_all do
    start_supervised(Worker)
    start_supervised({Task.Supervisor, name: TdDd.TaskSupervisor})
    :ok
  end

  describe "upload profiling" do
    setup %{fixture: fixture} do
      profiling = %Plug.Upload{path: fixture <> "/profiles.csv"}
      {:ok, profiling: profiling}
    end

    @tag authentication: [role: "service"]
    @tag fixture: "test/fixtures/profiling"
    test "uploads profiles for data structures", %{
      conn: conn,
      profiling: profiling
    } do
      sys1 = insert(:system, external_id: "SYS1", name: "SYS1")

      insert(:data_structure, external_id: "DS1", system_id: sys1.id)
      insert(:data_structure, external_id: "DS2", system_id: sys1.id)
      insert(:data_structure, external_id: "DS3", system_id: sys1.id)

      assert conn
             |> post(Routes.profile_path(conn, :upload), profiling: profiling)
             |> response(:accepted)

      # waits for loader to complete
      Worker.await(20_000)
      assert Enum.count(Profiles.list_profiles()) == 3
    end
  end

  describe "create profiling" do
    @tag authentication: [role: "service"]
    test "creates profiling", %{conn: conn} do
      %{id: id, external_id: external_id} = insert(:data_structure)
      profile = %{"foo" => "bar"}

      assert %{"data" => %{"data_structure_id" => ^id, "value" => ^profile}} =
               conn
               |> post(Routes.data_structure_profile_path(conn, :create, external_id),
                 profile: profile
               )
               |> json_response(:created)
    end
  end
end
