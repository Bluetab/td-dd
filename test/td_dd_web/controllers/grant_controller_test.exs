defmodule TdDdWeb.GrantControllerTest do
  use TdDdWeb.ConnCase

  alias TdDd.Grants.Grant

  @create_attrs %{
    detail: %{},
    end_date: "2010-04-17T14:00:00.000000Z",
    start_date: "2010-04-17T14:00:00.000000Z",
    user_id: 42
  }
  @update_attrs %{
    detail: %{},
    end_date: "2011-05-18T15:01:01.000000Z",
    start_date: "2011-05-18T15:01:01.000000Z",
    user_id: 43
  }
  @invalid_attrs %{detail: nil, end_date: nil, start_date: nil, user_id: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create grant" do
    setup assigns do
      case assigns do
        %{domain: %{id: domain_id}} ->
          [data_structure: insert(:data_structure, domain_id: domain_id)]

        _ ->
          [data_structure: insert(:data_structure)]
      end
    end

    @tag authentication: [role: "admin"]
    test "renders grant when data is valid", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id}
    } do
      conn =
        post(conn, Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
          grant: @create_attrs
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "detail" => %{},
               "end_date" => "2010-04-17T14:00:00.000000Z",
               "start_date" => "2010-04-17T14:00:00.000000Z",
               "user_id" => 42
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions can create a grant", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id}
    } do
      conn =
        post(conn, Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
          grant: @create_attrs
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "detail" => %{},
               "end_date" => "2010-04-17T14:00:00.000000Z",
               "start_date" => "2010-04-17T14:00:00.000000Z",
               "user_id" => 42
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions cannot create a grant with a structure in other domain", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{external_id: data_structure_external_id} =
        insert(:data_structure, domain_id: domain_id + 1)

      conn =
        post(conn, Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
          grant: @create_attrs
        )

      assert json_response(conn, :forbidden)["errors"] != %{}
    end

    @tag authentication: [role: "non_admin"]
    test "user without permissions can't create a grant", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id}
    } do
      conn =
        post(conn, Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
          grant: @create_attrs
        )

      assert json_response(conn, :forbidden)["errors"] != %{}
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id}
    } do
      conn =
        post(conn, Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
          grant: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update grant" do
    setup [:create_grant]

    @tag authentication: [role: "admin"]
    test "renders grant when data is valid", %{
      conn: conn,
      grant: %Grant{id: id, user_id: user_id} = grant
    } do
      conn = put(conn, Routes.grant_path(conn, :update, grant), grant: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "detail" => %{},
               "end_date" => "2011-05-18T15:01:01.000000Z",
               "start_date" => "2011-05-18T15:01:01.000000Z",
               "user_id" => ^user_id
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn, grant: grant} do
      conn = put(conn, Routes.grant_path(conn, :update, grant), grant: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete grant" do
    setup [:create_grant]

    @tag authentication: [role: "admin"]
    test "deletes chosen grant", %{conn: conn, grant: grant} do
      conn = delete(conn, Routes.grant_path(conn, :delete, grant))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.grant_path(conn, :show, grant))
      end
    end
  end

  defp create_grant(_) do
    grant = insert(:grant)
    %{grant: grant}
  end
end
