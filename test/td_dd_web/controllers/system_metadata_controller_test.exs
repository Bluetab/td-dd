defmodule TdDdWeb.SystemMetadataControllerTest do
  use TdDdWeb.ConnCase

  import Mox

  setup do
    Application.put_env(:td_dd, :loader_worker, TdDd.Loader.MockWorker)
    Mox.defmock(TdDd.Loader.MockWorker, for: TdDd.Loader.Worker.Behaviour)
    Mox.verify_on_exit!()
    :ok
  end

  describe "upload by system" do
    @tag authentication: [role: "service"]
    test "calls worker with files and options for multipart create request", %{conn: conn} do
      %{id: system_id, external_id: system_external_id} = insert(:system)

      params = %{
        data_structures: upload(".gitignore"),
        data_structure_relations: upload(".gitignore"),
        domain: "domain",
        source: "source"
      }

      expect(TdDd.Loader.MockWorker, :load, fn structures_file,
                                               _fields_file,
                                               relations_file,
                                               audit,
                                               opts ->
        assert String.ends_with?(structures_file, ".gitignore")
        assert String.ends_with?(relations_file, ".gitignore")
        assert %{last_change_by: _, ts: _} = audit
        assert [source: "source", domain: "domain", system_id: ^system_id, worker: _worker] = opts
        :ok
      end)

      assert conn
             |> Plug.Conn.put_req_header("content-type", "multipart/form-data")
             |> post(Routes.system_metadata_path(conn, :create, system_external_id), params)
             |> response(:accepted)
    end
  end

  defp upload(path) do
    %Plug.Upload{path: path, filename: Path.basename(path)}
  end
end
