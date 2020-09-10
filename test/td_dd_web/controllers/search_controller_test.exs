defmodule TdDdWeb.SearchControllerTest do
  use TdDdWeb.ConnCase

  alias TdDd.DataStructures.PathCache
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuthService

  import Routes

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    start_supervised(PathCache)
    :ok
  end

  describe "search" do
    @tag :admin_authenticated
    test "search with query performs ngram search on name", %{conn: conn} do
      insert(:data_structure_version,
        name: "foo",
        type: "type",
        metadata: %{"foo" => "value"}
      )

      insert(:data_structure_version,
        name: "baz",
        type: "type",
        metadata: %{"bar" => "value", "Xyz" => "value"}
      )

      insert(:data_structure_version,
        name: "bar",
        type: "new_type",
        metadata: %{"baz" => "value"}
      )

      assert %{"data" => [_ | _] = fields} =
               conn
               |> post(search_path(conn, :search_structures_metadata_fields), %{
                 "filters" => %{"type.raw" => ["type"]}
               })
               |> json_response(:ok)

      assert Enum.all?(["foo", "bar", "Xyz"], &(&1 in fields))
    end
  end
end
