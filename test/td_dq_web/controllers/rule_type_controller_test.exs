defmodule TdDqWeb.RuleTypeControllerTest do
  use TdDqWeb.ConnCase

  alias TdDq.Rules
  alias TdDq.Rules.RuleType

  import TdDqWeb.Authentication, only: :functions

  @create_attrs %{name: "some name", params: %{}}
  @update_attrs %{name: "some updated name", params: %{}}
  @invalid_attrs %{name: nil, params: nil}

  def fixture(:quality_rule_type) do
    {:ok, quality_rule_type} = Rules.create_quality_rule_type(@create_attrs)
    quality_rule_type
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all quality_rule_type", %{conn: conn} do
      conn = get conn, rule_type_path(conn, :index)
      assert response(conn, 200)
    end
  end

  describe "create quality_rule_type" do
    @tag :admin_authenticated
    test "renders quality_rule_type when data is valid", %{conn: conn} do
      conn = post conn, rule_type_path(conn, :create), quality_rule_type: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get conn, rule_type_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "name" => "some name",
        "params" => %{}}
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, rule_type_path(conn, :create), quality_rule_type: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update quality_rule_type" do
    setup [:create_quality_rule_type]

    @tag :admin_authenticated
    test "renders quality_rule_type when data is valid", %{conn: conn, quality_rule_type: %RuleType{id: id} = quality_rule_type} do
      conn = put conn, rule_type_path(conn, :update, quality_rule_type), quality_rule_type: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get conn, rule_type_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "name" => "some updated name",
        "params" => %{}}
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn, quality_rule_type: quality_rule_type} do
      conn = put conn, rule_type_path(conn, :update, quality_rule_type), quality_rule_type: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete quality_rule_type" do
    setup [:create_quality_rule_type]

    @tag :admin_authenticated
    test "deletes chosen quality_rule_type", %{conn: conn, quality_rule_type: quality_rule_type} do
      conn = delete conn, rule_type_path(conn, :delete, quality_rule_type)
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent 404, fn ->
        get conn, rule_type_path(conn, :show, quality_rule_type)
      end
    end
  end

  describe "create duplicated quality_rule_type" do
    @tag :admin_authenticated
    test "renders quality_rule_type when data is valid", %{conn: conn} do
      conn = post conn, rule_type_path(conn, :create), quality_rule_type: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get conn, rule_type_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "name" => "some name",
        "params" => %{}}

      conn = recycle_and_put_headers(conn)
      conn = post conn, rule_type_path(conn, :create), quality_rule_type: @create_attrs
      assert %{"errors" => %{"detail" => "Internal server error"}} = json_response(conn, 422)
    end
  end

  defp create_quality_rule_type(_) do
    quality_rule_type = fixture(:quality_rule_type)
    {:ok, quality_rule_type: quality_rule_type}
  end
end
