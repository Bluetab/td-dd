defmodule TdDdWeb.GrantsControllerTest do
  use TdDdWeb.ConnCase

  @moduletag sandbox: :shared

  @user_id 123_456
  @create_attrs %{
    detail: %{},
    end_date: Date.utc_today() |> Date.add(1),
    start_date: "2010-04-17",
    user_id: @user_id,
    source_user_name: "source_user_name_#{@user_id}"
  }

  @invalid_attrs %{detail: nil, end_date: nil, start_date: nil, source_user_name: nil}

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)

    CacheHelpers.insert_user(id: @user_id)
    :ok
  end

  describe "bulk grant" do
    setup :create_data_structure

    @tag authentication: [role: "admin"]
    test "when data is valid", %{
      conn: conn,
      data_structure: %{id: _data_structure_id, external_id: data_structure_external_id}
    } do
      %{
        start_date: start_date,
        end_date: end_date,
        user_id: user_id,
        source_user_name: source_user_name
      } =
        create_attr =
        @create_attrs
        |> Map.put(:op, "add")
        |> Map.put(:data_structure_external_id, data_structure_external_id)

      assert conn
             |> patch(Routes.grants_path(conn, :update),
               grants: [create_attr]
             )
             |> response(:ok)

      string_end_date = Date.to_string(end_date)

      assert %{
               "data" => [
                 %{
                   "start_date" => ^start_date,
                   "end_date" => ^string_end_date,
                   "user_id" => ^user_id,
                   "source_user_name" => ^source_user_name
                 }
               ]
             } =
               conn
               |> get(Routes.grant_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "when operator is invalid", %{
      conn: conn,
      data_structure: %{id: _data_structure_id, external_id: data_structure_external_id}
    } do
      create_attr =
        @create_attrs
        |> Map.put(:op, "invalid_op")
        |> Map.put(:data_structure_external_id, data_structure_external_id)

      assert %{"error" => ["not_found", "invalid operator", "invalid_op"]} =
               conn
               |> patch(Routes.grants_path(conn, :update),
                 grants: [create_attr]
               )
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "when operator is missing", %{
      conn: conn,
      data_structure: %{id: _data_structure_id, external_id: data_structure_external_id}
    } do
      create_attr =
        Map.put(@create_attrs, :data_structure_external_id, data_structure_external_id)

      assert %{"error" => ["not_found", "missing operator"]} =
               conn
               |> patch(Routes.grants_path(conn, :update),
                 grants: [create_attr]
               )
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "when data is invalid", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id}
    } do
      invalid_attrs =
        @invalid_attrs
        |> Map.put(:op, "add")
        |> Map.put(:data_structure_external_id, data_structure_external_id)

      assert %{"errors" => errors} =
               conn
               |> patch(Routes.grants_path(conn, :update),
                 grants: [invalid_attrs]
               )
               |> json_response(:unprocessable_entity)

      assert %{"start_date" => ["can't be blank"], "source_user_name" => ["can't be blank"]} =
               errors
    end

    @tag authentication: [role: "admin"]
    test "when data_structure_external_id is invalid", %{
      conn: conn
    } do
      invalid_attrs =
        @invalid_attrs
        |> Map.put(:op, "add")
        |> Map.put(:data_structure_external_id, "zoo")

      assert %{"error" => ["not_found", "DataStructure"]} =
               conn
               |> patch(Routes.grants_path(conn, :update),
                 grants: [invalid_attrs]
               )
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "non_admin"]
    test "user without permissions cannot bulk grants", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id}
    } do
      create_attr =
        @create_attrs
        |> Map.put(:op, "add")
        |> Map.put(:data_structure_external_id, data_structure_external_id)

      assert conn
             |> patch(Routes.grants_path(conn, :update), grants: [create_attr])
             |> json_response(:forbidden)
    end
  end

  defp create_data_structure(context) do
    case context do
      %{domain: %{id: domain_id}} ->
        [data_structure: insert(:data_structure, domain_id: domain_id)]

      _ ->
        [data_structure: insert(:data_structure)]
    end
  end
end
