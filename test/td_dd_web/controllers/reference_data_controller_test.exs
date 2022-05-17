defmodule TdDdWeb.ReferenceDataControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  @path "test/fixtures/reference_data/dataset1.csv"

  describe "GET /api/reference_data" do
    @tag authentication: [role: "user"]
    test "returns forbidden for regular user", %{conn: conn} do
      assert conn
             |> get(Routes.reference_data_path(conn, :index))
             |> response(:forbidden)
    end

    @tag authentication: [role: "service"]
    test "returns data for service account", %{conn: conn} do
      %{id: id} = insert(:reference_dataset)

      assert %{"data" => data} =
               conn
               |> get(Routes.reference_data_path(conn, :index))
               |> json_response(:ok)

      assert [%{"id" => ^id, "row_count" => 2}] = data
    end
  end

  describe "GET /api/reference_data/:id" do
    @tag authentication: [role: "user"]
    test "returns forbidden for regular user", %{conn: conn} do
      assert conn
             |> get(Routes.reference_data_path(conn, :show, "123"))
             |> response(:forbidden)
    end

    @tag authentication: [role: "service"]
    test "returns data for service account", %{conn: conn} do
      %{id: id} = insert(:reference_dataset)

      assert %{"data" => data} =
               conn
               |> get(Routes.reference_data_path(conn, :show, "#{id}"))
               |> json_response(:ok)

      assert %{"id" => ^id, "name" => _, "headers" => _, "rows" => _, "row_count" => 2} = data
    end
  end

  describe "DELETE /api/reference_data/:id" do
    for role <- ["user", "service"] do
      @tag authentication: [role: role]
      test "returns forbidden for #{role} account", %{conn: conn} do
        assert conn
               |> delete(Routes.reference_data_path(conn, :delete, "123"))
               |> response(:forbidden)
      end
    end

    @tag authentication: [role: "admin"]
    test "deletes an existing reference dataset", %{conn: conn} do
      %{id: id} = insert(:reference_dataset)

      assert conn
             |> delete(Routes.reference_data_path(conn, :show, "#{id}"))
             |> response(:no_content)
    end
  end

  describe "POST /api/reference_data" do
    for role <- ["user", "service"] do
      @tag authentication: [role: role]
      test "returns forbidden for #{role} account", %{conn: conn} do
        params = %{"name" => "foo", "dataset" => %Plug.Upload{}}

        assert conn
               |> post(Routes.reference_data_path(conn, :create), params)
               |> response(:forbidden)
      end
    end

    @tag authentication: [role: "admin"]
    test "creates a new reference dataset", %{conn: conn} do
      params = %{"name" => "foo", "dataset" => %Plug.Upload{path: @path}}

      assert %{"data" => data} =
               conn
               |> post(Routes.reference_data_path(conn, :create), params)
               |> json_response(:created)

      assert %{"id" => _, "name" => "foo", "headers" => _, "rows" => _} = data
    end
  end

  describe "PUT /api/reference_data/:id" do
    for role <- ["user", "service"] do
      @tag authentication: [role: role]
      test "returns forbidden for #{role} account", %{conn: conn} do
        params = %{"name" => "foo", "dataset" => %Plug.Upload{}}

        assert conn
               |> put(Routes.reference_data_path(conn, :update, "123"), params)
               |> response(:forbidden)
      end
    end

    @tag authentication: [role: "admin"]
    test "updates an existing reference dataset", %{conn: conn} do
      %{id: id, name: name} = insert(:reference_dataset)
      params = %{"dataset" => %Plug.Upload{path: @path}}

      assert %{"data" => data} =
               conn
               |> put(Routes.reference_data_path(conn, :update, "#{id}"), params)
               |> json_response(:ok)

      assert %{"id" => ^id, "name" => ^name, "headers" => _, "rows" => _} = data
    end
  end
end
