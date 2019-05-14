defmodule TdDqWeb.RuleTypeControllerTest do
  use TdDqWeb.ConnCase

  alias TdDq.Rules
  alias TdDq.Rules.RuleType

  import TdDqWeb.Authentication, only: :functions

  @create_attrs %{name: "some name", params: %{}}
  @update_attrs %{name: "some updated name", params: %{}}
  @invalid_attrs %{name: nil, params: nil}

  def fixture(:rule_type) do
    {:ok, rule_type} = Rules.create_rule_type(@create_attrs)
    rule_type
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all rule_type", %{conn: conn} do
      conn = get(conn, rule_type_path(conn, :index))
      assert response(conn, 200)
    end
  end

  describe "create rule_type" do
    @tag :admin_authenticated
    test "renders rule_type when data is valid", %{conn: conn} do
      conn = post conn, rule_type_path(conn, :create), rule_type: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, rule_type_path(conn, :show, id))

      assert json_response(conn, 200)["data"] == %{
               "id" => id,
               "name" => "some name",
               "params" => %{}
             }
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, rule_type_path(conn, :create), rule_type: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update rule_type" do
    setup [:create_rule_type]

    @tag :admin_authenticated
    test "renders rule_type when data is valid", %{
      conn: conn,
      rule_type: %RuleType{id: id} = rule_type
    } do
      conn = put conn, rule_type_path(conn, :update, rule_type), rule_type: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, rule_type_path(conn, :show, id))

      assert json_response(conn, 200)["data"] == %{
               "id" => id,
               "name" => "some updated name",
               "params" => %{}
             }
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn, rule_type: rule_type} do
      conn = put conn, rule_type_path(conn, :update, rule_type), rule_type: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete rule_type" do
    setup [:create_rule_type]

    @tag :admin_authenticated
    test "deletes chosen rule_type", %{conn: conn, rule_type: rule_type} do
      conn = delete(conn, rule_type_path(conn, :delete, rule_type))
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent 404, fn ->
        get(conn, rule_type_path(conn, :show, rule_type))
      end
    end
  end

  describe "create duplicated rule_type" do
    @tag :admin_authenticated
    test "renders rule_type when data is valid", %{conn: conn} do
      conn = post conn, rule_type_path(conn, :create), rule_type: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get(conn, rule_type_path(conn, :show, id))

      assert json_response(conn, 200)["data"] == %{
               "id" => id,
               "name" => "some name",
               "params" => %{}
             }

      conn = recycle_and_put_headers(conn)
      conn = post conn, rule_type_path(conn, :create), rule_type: @create_attrs
      assert %{"errors" => %{"detail" => "Unprocessable Entity"}} = json_response(conn, 422)
    end
  end

  defp create_rule_type(_) do
    rule_type = fixture(:rule_type)
    {:ok, rule_type: rule_type}
  end
end
