defmodule TdDdWeb.GroupControllerTest do
  use TdDdWeb.ConnCase

  import Mox

  setup do
    stub(MockClusterHandler, :call, fn :ai, TdAi.Indices, :exists_enabled?, [] ->
      {:ok, true}
    end)

    [system: insert(:system)]
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "index", %{conn: conn, system: %{external_id: external_id}} do
      assert %{"data" => []} =
               conn
               |> get(Routes.system_group_path(conn, :index, external_id))
               |> json_response(:ok)
    end
  end

  describe "delete" do
    @tag authentication: [role: "admin"]
    test "delete", %{conn: conn, system: %{id: system_id, external_id: external_id}} do
      insert(:data_structure_version,
        data_structure: build(:data_structure, system_id: system_id),
        group: "group_name"
      )

      assert conn
             |> delete(Routes.system_group_path(conn, :delete, external_id, "group_name"))
             |> response(:no_content)
    end
  end
end
