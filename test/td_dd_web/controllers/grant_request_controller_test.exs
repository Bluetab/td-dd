defmodule TdDdWeb.GrantRequestControllerTest do
  use TdDdWeb.ConnCase

  alias TdDd.Grants.GrantRequest

  @create_attrs %{
    filters: %{},
    metadata: %{}
  }
  @update_attrs %{
    filters: %{},
    metadata: %{}
  }
  @template_name "grant_request_controller_test_template"

  setup %{conn: conn} do
    CacheHelpers.insert_template(name: @template_name)
    [conn: put_req_header(conn, "accept", "application/json")]
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all grant_requests", %{conn: conn} do
      _other_group_request = insert(:grant_request)
      grant_request_group = insert(:grant_request_group)
      conn = get(conn, Routes.grant_request_group_request_path(conn, :index, grant_request_group))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create grant_request" do
    @tag authentication: [role: "admin"]
    test "renders grant_request when data is valid", %{conn: conn} do
      grant_request_group = insert(:grant_request_group, type: @template_name)
      %{id: data_structure_id} = insert(:data_structure)

      metadata = %{
        "list" => "one",
        "string" => "bar"
      }

      attrs =
        @create_attrs
        |> Map.put(:data_structure_id, data_structure_id)
        |> Map.put(:metadata, metadata)

      conn =
        post(conn, Routes.grant_request_group_request_path(conn, :create, grant_request_group),
          grant_request: attrs
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.grant_request_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "filters" => %{},
               "metadata" => ^metadata
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "non-admin cannot create grant_request", %{conn: conn} do
      grant_request_group = insert(:grant_request_group)
      %{id: data_structure_id} = insert(:data_structure)

      attrs = Map.put(@create_attrs, :data_structure_id, data_structure_id)

      conn =
        post(conn, Routes.grant_request_group_request_path(conn, :create, grant_request_group),
          grant_request: attrs
        )

      assert response(conn, :forbidden)
    end

    @tag authentication: [role: "admin"]
    test "fails to create grant with invalid metadata", %{conn: conn} do
      grant_request_group = insert(:grant_request_group, type: @template_name)
      %{id: data_structure_id} = insert(:data_structure)
      attrs = Map.put(@create_attrs, :data_structure_id, data_structure_id)

      conn =
        post(conn, Routes.grant_request_group_request_path(conn, :create, grant_request_group),
          grant_request: attrs
        )

      assert %{"errors" => %{"metadata" => ["invalid content"]}} = json_response(conn, 422)
    end

    @tag authentication: [role: "admin"]
    test "fails on invalid grant_request_group_id", %{conn: conn} do
      %{id: data_structure_id} = insert(:data_structure)
      attrs = Map.put(@create_attrs, :data_structure_id, data_structure_id)

      conn =
        post(conn, Routes.grant_request_group_request_path(conn, :create, 888),
          grant_request: attrs
        )

      assert json_response(conn, :not_found)["message"] == "GrantRequestGroup"
    end
  end

  describe "update grant_request" do
    setup [:create_grant_request]

    @tag authentication: [role: "admin"]
    test "renders grant_request when data is valid", %{
      conn: conn,
      grant_request: %GrantRequest{id: id} = grant_request
    } do
      conn =
        put(
          conn,
          Routes.grant_request_path(
            conn,
            :update,
            grant_request
          ),
          grant_request: @update_attrs
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.grant_request_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "filters" => %{},
               "metadata" => %{}
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [user_name: "non_admin"]
    test "non admin user cannot update grant_request", %{
      conn: conn,
      grant_request: %GrantRequest{} = grant_request
    } do
      conn =
        put(
          conn,
          Routes.grant_request_path(
            conn,
            :update,
            grant_request
          ),
          grant_request: @update_attrs
        )

      assert response(conn, :forbidden)
    end
  end

  describe "delete grant_request" do
    setup [:create_grant_request]

    @tag authentication: [role: "admin"]
    test "deletes chosen grant_request", %{conn: conn, grant_request: grant_request} do
      conn =
        delete(
          conn,
          Routes.grant_request_path(
            conn,
            :delete,
            grant_request
          )
        )

      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(
          conn,
          Routes.grant_request_path(
            conn,
            :show,
            grant_request
          )
        )
      end
    end

    @tag authentication: [user_name: "non_admin"]
    test "non admin user cannot delete grant_request", %{conn: conn, grant_request: grant_request} do
      conn =
        delete(
          conn,
          Routes.grant_request_path(
            conn,
            :delete,
            grant_request
          )
        )

      assert response(conn, :forbidden)
    end
  end

  defp create_grant_request(_) do
    grant_request = insert(:grant_request)
    %{grant_request: grant_request}
  end
end
