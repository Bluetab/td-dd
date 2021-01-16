defmodule TdDdWeb.SearchControllerTest do
  use TdDdWeb.ConnCase

  import Routes

  describe "search" do
    @tag :admin_authenticated
    test "search_structures_metadata_fields (admin)", %{conn: conn} do
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
                 "filters" => %{"type" => ["type"]}
               })
               |> json_response(:ok)

      assert Enum.all?(["foo", "bar", "Xyz"], &(&1 in fields))
    end

    @tag authenticated_user: "user1"
    test "search_structures_metadata_fields (non-admin user)", %{conn: conn} do
      assert conn
             |> post(search_path(conn, :search_structures_metadata_fields), %{
               "filters" => %{"type" => ["type"]}
             })
             |> response(:forbidden)
    end
  end
end
