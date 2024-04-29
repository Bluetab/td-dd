defmodule TdDdWeb.SystemMetadataControllerTest do
  use TdDdWeb.ConnCase

  import Mox

  setup_all do
    Application.put_env(:td_dd, :loader_worker, TdDd.Loader.MockWorker)
    Mox.defmock(TdDd.Loader.MockWorker, for: TdDd.Loader.Worker.Behaviour)
    :ok
  end

  setup :verify_on_exit!

  describe "upload by system" do
    @tag authentication: [role: "service"]
    test "calls worker with csv files and options for multipart create request", %{conn: conn} do
      %{id: system_id, external_id: system_external_id} = insert(:system)

      params = %{
        "data_structures" => upload(".gitignore"),
        "data_structure_relations" => upload(".gitignore"),
        "domain" => "domain",
        "source" => "source"
      }

      expect(TdDd.Loader.MockWorker, :load, fn structures_file,
                                               _fields_file,
                                               relations_file,
                                               audit,
                                               opts ->
        assert String.ends_with?(structures_file, ".gitignore")
        assert String.ends_with?(relations_file, ".gitignore")
        assert %{last_change_by: _, ts: _} = audit
        assert opts[:domain] == "domain"
        assert opts[:source] == "source"
        assert opts[:system_id] == system_id
        :ok
      end)

      assert conn
             |> Plug.Conn.put_req_header("content-type", "multipart/form-data; boundary=boundary")
             |> post(Routes.system_metadata_path(conn, :create, system_external_id), params)
             |> response(:accepted)
    end

    @tag authentication: [role: "service"]
    test "calls worker with valid json data", %{conn: conn} do
      %{id: system_id, external_id: system_external_id} = insert(:system)

      body = %{
        "data_structures" => %{"foo" => "bar"},
        "data_structure_relations" => %{"bar" => "baz"},
        "domain" => "domain",
        "source" => "source"
      }

      expect(TdDd.Loader.MockWorker, :load, fn %{id: ^system_id},
                                               %{"system_id" => _} = params,
                                               audit,
                                               opts ->
        assert body == Map.delete(params, "system_id")
        assert %{ts: _, last_change_by: _} = audit
        assert opts[:domain] == "domain"
        assert opts[:source] == "source"
        :ok
      end)

      assert conn
             |> post(Routes.system_metadata_path(conn, :create, system_external_id, body))
             |> response(:accepted)
    end

    @tag authentication: [role: "service"]
    test "calls worker with inherit_domains true on valid json data", %{conn: conn} do
      %{id: system_id, external_id: system_external_id} = insert(:system)

      body = %{
        "data_structures" => %{"foo" => "bar"},
        "data_structure_relations" => %{"bar" => "baz"},
        "domain" => "domain",
        "source" => "source",
        "inherit_domains" => "true"
      }

      expect(TdDd.Loader.MockWorker, :load, fn %{id: ^system_id},
                                               %{"system_id" => _} = params,
                                               audit,
                                               opts ->
        assert body == Map.delete(params, "system_id")
        assert %{ts: _, last_change_by: _} = audit
        assert opts[:domain] == "domain"
        assert opts[:source] == "source"
        assert opts[:inherit_domains] == true
        :ok
      end)

      assert conn
             |> post(Routes.system_metadata_path(conn, :create, system_external_id, body))
             |> response(:accepted)
    end
  end

  describe "PATCH /api/systems/:external_id/metadata" do
    @tag authentication: [role: "service"]
    test "calls worker with valid metadata json data", %{conn: conn} do
      %{id: system_id, external_id: system_external_id} = insert(:system)

      body = %{"op" => "merge", "values" => [%{"foo" => "bar"}]}

      expect(TdDd.Loader.MockWorker, :load, fn %{id: ^system_id},
                                               %{"system_id" => _} = params,
                                               audit,
                                               opts ->
        assert body == Map.delete(params, "system_id")
        assert %{ts: _, last_change_by: _} = audit
        assert opts == [operation: "merge"]
        :ok
      end)

      assert conn
             |> patch(Routes.system_metadata_path(conn, :update, system_external_id, body))
             |> response(:accepted)
    end
  end
end
