defmodule TdDdWeb.LabelControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  @tag authentication: [role: "user"]
  test "create label: permission", %{conn: conn} do
    conn
    |> post(
      Routes.label_path(conn, :create),
      %{"name" => "label_name"}
    )
    |> json_response(:forbidden)
  end

  @tag authentication: [role: "service"]
  test "create label", %{conn: conn} do
    assert %{"data" => data} =
             conn
             |> post(
               Routes.label_path(conn, :create),
               %{"name" => "label_name"}
             )
             |> json_response(:created)

    assert %{"id" => _id, "name" => "label_name"} = data
  end

  @tag authentication: [role: "service"]
  test "create: duplicated name", %{conn: conn} do
    insert(:label, name: "label_name")

    assert %{"errors" => %{"name" => ["has already been taken"]}} =
             conn
             |> post(
               Routes.label_path(conn, :create),
               %{"name" => "label_name"}
             )
             |> json_response(:unprocessable_entity)
  end

  @tag authentication: [role: "service"]
  test "delete label by id", %{conn: conn} do
    label = insert(:label, name: "label_name")

    assert conn
           |> delete(Routes.label_path(conn, :delete, label))
           |> response(:no_content)
  end

  @tag authentication: [role: "service"]
  test "delete label by name", %{conn: conn} do
    insert(:label, name: "label_name")

    assert conn
           |> delete(Routes.label_path(conn, :delete_by_name, %{"name" => "label_name"}))
           |> response(:no_content)
  end
end
