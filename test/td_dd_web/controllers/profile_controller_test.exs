defmodule TdDdWeb.ProfileControllerTest do
  use TdDdWeb.ConnCase

  alias TdDd.Loader.Worker
  alias TdDd.Profiles

  setup_all do
    start_supervised(Worker)
    start_supervised({Task.Supervisor, name: TdDd.TaskSupervisor})
    :ok
  end

  describe "upload profiling" do
    setup %{fixture: fixture} do
      profiling = %Plug.Upload{path: fixture <> "/profiles.csv"}
      [profiling: profiling]
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
      %{id: id} = insert(:data_structure)
      profile = %{"foo" => "bar"}

      assert %{"data" => %{"data_structure_id" => ^id, "value" => ^profile}} =
               conn
               |> post(Routes.data_structure_profile_path(conn, :create, id),
                 profile: profile
               )
               |> json_response(:created)
    end

    @tag authentication: [role: "service"]
    test "not found when structure does not exist", %{conn: conn} do
      id = System.unique_integer([:positive])
      profile = %{"foo" => "bar"}

      assert_raise Ecto.NoResultsError, fn ->
        post(conn, Routes.data_structure_profile_path(conn, :create, id), profile: profile)
      end
    end
  end

  defp ordered_profile_ids(profiles) do
    profiles
    |> Enum.map(&profile_id/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort()
  end

  defp profile_id(%{"id" => id}), do: id
  defp profile_id(%{id: id}), do: id
  defp profile_id(_), do: nil

  describe "index profiling by scroll" do
    @tag authentication: [role: "admin"]
    test "index renders profile", %{conn: conn} do
      updated_at = "2022-02-22T02:22:20"

      %{
        id: id,
        data_structure_id: data_structure_id,
        value: value
      } = insert(:profile, updated_at: updated_at)

      assert %{"data" => [profile]} =
               conn
               |> post(Routes.profile_path(conn, :search))
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "data_structure_id" => ^data_structure_id,
               "value" => ^value,
               "updated_at" => ^updated_at
             } = profile
    end

    @tag authentication: [role: "admin"]
    test "index without params lists all profiles", %{conn: conn} do
      profiles = Enum.map(1..8, fn _ -> insert(:profile) end)

      assert %{"data" => data} =
               conn
               |> post(Routes.profile_path(conn, :search))
               |> json_response(:ok)

      assert ordered_profile_ids(profiles) == ordered_profile_ids(data)
    end

    @tag authentication: [role: "service"]
    test "service account can list profiles", %{conn: conn} do
      profiles = Enum.map(1..8, fn _ -> insert(:profile) end)

      assert %{"data" => data} =
               conn
               |> post(Routes.profile_path(conn, :search))
               |> json_response(:ok)

      assert ordered_profile_ids(profiles) == ordered_profile_ids(data)
    end

    @tag authentication: [role: "user"]
    test "user account cannot list profiles", %{conn: conn} do
      Enum.map(1..8, fn _ -> insert(:profile) end)

      assert conn
             |> post(Routes.profile_path(conn, :search))
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "index limit param", %{conn: conn} do
      first_5_profiles = Enum.map(1..5, fn _ -> insert(:profile) end)
      _another_5_profiles = Enum.map(1..5, fn _ -> insert(:profile) end)

      assert %{"data" => data} =
               conn
               |> post(Routes.profile_path(conn, :search), %{limit: 5})
               |> json_response(:ok)

      assert ordered_profile_ids(first_5_profiles) == ordered_profile_ids(data)
    end

    @tag authentication: [role: "admin"]
    test "index offset param", %{conn: conn} do
      _first_5_profiles = Enum.map(1..5, fn _ -> insert(:profile) end)
      another_5_profiles = Enum.map(1..5, fn _ -> insert(:profile) end)

      assert %{"data" => data} =
               conn
               |> post(Routes.profile_path(conn, :search), %{offset: 5})
               |> json_response(:ok)

      assert ordered_profile_ids(another_5_profiles) == ordered_profile_ids(data)
    end

    @tag authentication: [role: "admin"]
    test "index since filter param", %{conn: conn} do
      _first_5_profiles =
        Enum.map(1..5, fn day -> insert(:profile, updated_at: "2000-01-0#{day}T00:00:00") end)

      another_5_profiles =
        Enum.map(6..9, fn day -> insert(:profile, updated_at: "2000-01-0#{day}T00:00:00") end)

      assert %{"data" => data} =
               conn
               |> post(Routes.profile_path(conn, :search), %{since: "2000-01-06T00:00:00"})
               |> json_response(:ok)

      assert ordered_profile_ids(another_5_profiles) == ordered_profile_ids(data)
    end
  end
end
