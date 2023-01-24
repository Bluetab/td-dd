defmodule TdDdWeb.ReferenceDataDownloadControllerTest do
  use TdDdWeb.ConnCase

  describe "GET /api/reference_data/:id/csv" do
    @tag authentication: [role: "user"]
    test "returns forbidden for regular user", %{conn: conn} do
      assert conn
             |> get(Routes.reference_data_reference_data_download_path(conn, :show, "123"))
             |> response(:forbidden)
    end

    @tag authentication: [role: "user", permissions: ["view_data_structure"]]
    test "returns data for user with permissions", %{conn: conn, domain: %{id: domain_id}} do
      %{id: id} = insert(:reference_dataset, domain_ids: [domain_id])

      assert data =
               conn
               |> get(Routes.reference_data_reference_data_download_path(conn, :show, "#{id}"))
               |> response(:ok)

      assert data == "FOO;BAR;BAZ\r\nfoo1;bar1;baz1\r\nfoo2;bar2;baz2\r\n"
    end

    @tag authentication: [role: "user", permissions: ["view_data_structure"]]
    test "returns forbidden for user without permission in domain", %{conn: conn, domain: %{id: domain_id}} do
      %{id: id} = insert(:reference_dataset, domain_ids: [domain_id + 1])

      assert conn
             |> get(Routes.reference_data_reference_data_download_path(conn, :show, "#{id}"))
             |> response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "returns data for admin account", %{conn: conn} do
      %{id: id} = insert(:reference_dataset)

      assert data =
               conn
               |> get(Routes.reference_data_reference_data_download_path(conn, :show, "#{id}"))
               |> response(:ok)

      assert data == "FOO;BAR;BAZ\r\nfoo1;bar1;baz1\r\nfoo2;bar2;baz2\r\n"
    end
  end
end
