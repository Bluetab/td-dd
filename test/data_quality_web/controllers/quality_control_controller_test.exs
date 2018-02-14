defmodule DataQualityWeb.QualityControlControllerTest do
  use DataQualityWeb.ConnCase

  alias DataQuality.QualityControls
  alias DataQuality.QualityControls.QualityControl
  import DataQualityWeb.Authentication, only: :functions

  @create_fixture_attrs %{business_concept_id: "some business_concept_id",
    description: "some description", goal: 42, minimum: 42, name: "some name",
    population: "some population", priority: "some priority", type: "some type",
    weight: 42, updated_by: "app-admin"}

  @create_attrs %{business_concept_id: "some business_concept_id",
    description: "some description", goal: 42, minimum: 42, name: "some name",
    population: "some population", priority: "some priority", type: "some type",
    weight: 42}

  @update_attrs %{business_concept_id: "some updated business_concept_id", description: "some updated description",
    goal: 43, minimum: 43, name: "some updated name", population: "some updated population",
    priority: "some updated priority", type: "some updated type", weight: 43}

  @invalid_attrs %{business_concept_id: nil, description: nil, goal: nil, minimum: nil,
    name: nil, population: nil, priority: nil, type: nil, weight: nil}

  @comparable_fields ["id", "business_concept_id", "description", "goal", "minimum", "name",
    "population", "priority", "type", "weight", "status", "version", "updated_by"]

  @admin_user_name "app-admin"

  def fixture(:quality_control) do
    {:ok, quality_control} = QualityControls.create_quality_control(@create_fixture_attrs)
    quality_control
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "lists all quality_controls", %{conn: conn} do
      conn = get conn, quality_control_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "verify token is required" do
    test "renders unauthenticated when no token", %{conn: conn} do
      conn = put_req_header(conn, "content-type", "application/json")
      conn = post conn, quality_control_path(conn, :create), quality_control: @create_attrs
      assert conn.status == 401
    end
  end

  describe "verify token secret key must be the one in config" do
    test "renders unauthenticated when passing token signed with invalid secret key", %{conn: conn} do
      #token with secret key SuperSecretTruedat2"
      jwt = "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJ0cnVlQkciLCJleHAiOjE1MTg2MDE2ODMsImlhdCI6MTUxODU5ODA4MywiaXNzIjoidHJ1ZUJHIiwianRpIjoiNTAzNmI5MTQtYmViOC00N2QyLWI4NGQtOTA2ZjMyMTQwMDRhIiwibmJmIjoxNTE4NTk4MDgyLCJzdWIiOiJhcHAtYWRtaW4iLCJ0eXAiOiJhY2Nlc3MifQ.0c_ZpzfiwUeRAbHe-34rvFZNjQoU_0NCMZ-T6r6_DUqPiwlp1H65vY-G1Fs1011ngAAVf3Xf8Vkqp-yOQUDTdw"
      conn = put_auth_headers(conn, jwt)
      conn = post conn, quality_control_path(conn, :create), quality_control: @create_attrs
      assert conn.status == 401
    end
  end

  describe "create quality_control" do
    @tag authenticated_user: @admin_user_name
    test "renders quality_control when data is valid", %{conn: conn} do
      conn = post conn, quality_control_path(conn, :create), quality_control: @create_fixture_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)
      conn = get conn, quality_control_path(conn, :show, id)
      comparable_fields = Map.take(json_response(conn, 200)["data"], @comparable_fields)
      assert comparable_fields == %{
        "id" => id,
        "business_concept_id" => "some business_concept_id",
        "description" => "some description",
        "goal" => 42,
        "minimum" => 42,
        "name" => "some name",
        "population" => "some population",
        "priority" => "some priority",
        "type" => "some type",
        "weight" => 42,
        "status" => "defined",
        "version" => 1,
        "updated_by" => @create_fixture_attrs.updated_by
      }
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, quality_control_path(conn, :create), quality_control: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update quality_control" do
    setup [:create_quality_control]

    @tag authenticated_user: @admin_user_name
    test "renders quality_control when data is valid", %{conn: conn, quality_control: %QualityControl{id: id} = quality_control} do
      conn = put conn, quality_control_path(conn, :update, quality_control), quality_control: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)
      conn = get conn, quality_control_path(conn, :show, id)
      comparable_fields = Map.take(json_response(conn, 200)["data"], @comparable_fields)
      assert comparable_fields == %{
        "id" => id,
        "business_concept_id" => "some updated business_concept_id",
        "description" => "some updated description",
        "goal" => 43,
        "minimum" => 43,
        "name" => "some updated name",
        "population" => "some updated population",
        "priority" => "some updated priority",
        "type" => "some updated type",
        "weight" => 43,
        "status" => "defined",
        "version" => 1,
        "updated_by" => @create_fixture_attrs.updated_by}
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn, quality_control: quality_control} do
      conn = put conn, quality_control_path(conn, :update, quality_control), quality_control: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete quality_control" do
    setup [:create_quality_control]

    @tag authenticated_user: @admin_user_name
    test "deletes chosen quality_control", %{conn: conn, quality_control: quality_control} do
      conn = delete conn, quality_control_path(conn, :delete, quality_control)
      assert response(conn, 204)
      conn = recycle_and_put_headers(conn)
      assert_error_sent 404, fn ->
        get conn, quality_control_path(conn, :show, quality_control)
      end
    end
  end

  defp create_quality_control(_) do
    quality_control = fixture(:quality_control)
    {:ok, quality_control: quality_control}
  end
end
