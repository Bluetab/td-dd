defmodule TdDqWeb.SegmentResultControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger_dq.json"

  setup_all do
    start_supervised(TdDq.Cache.RuleLoader)
    start_supervised(TdDd.Search.MockIndexWorker)
    :ok
  end

  describe "GET /api/segment_results" do
    @tag authentication: [role: "service"]
    test "service account can view segment results", %{conn: conn, swagger_schema: schema} do
      %{id: parent_id_1} = insert(:rule_result)
      %{id: parent_id_2} = insert(:rule_result)
      insert(:segment_result, parent_id: parent_id_1)
      insert(:segment_result, parent_id: parent_id_1)
      insert(:segment_result, parent_id: parent_id_2)

      assert %{"data" => data} =
               conn
               |> get(Routes.segment_result_path(conn, :index))
               |> validate_resp_schema(schema, "SegmentResultResponse")
               |> json_response(:ok)

      assert [
               %{"parent_id" => ^parent_id_1},
               %{"parent_id" => ^parent_id_1},
               %{"parent_id" => ^parent_id_2}
             ] = data

      assert length(data) == 3
    end
  end

  describe "GET /api/rule_results/segment_results/" do
    @tag authentication: [role: "service"]
    test "service account can view segments rule results", %{conn: conn, swagger_schema: schema} do
      %{id: parent_id_1} = insert(:rule_result)
      %{id: parent_id_2} = insert(:rule_result)
      insert(:segment_result, parent_id: parent_id_1)
      insert(:segment_result, parent_id: parent_id_1)
      insert(:segment_result, parent_id: parent_id_1)
      insert(:segment_result, parent_id: parent_id_2)
      insert(:segment_result, parent_id: parent_id_2)

      assert %{"data" => [_ | _] = data} =
               conn
               |> get(Routes.rule_result_segment_result_path(conn, :index, parent_id_1))
               |> validate_resp_schema(schema, "SegmentResultResponse")
               |> json_response(:ok)

      assert [
               %{"parent_id" => ^parent_id_1},
               %{"parent_id" => ^parent_id_1},
               %{"parent_id" => ^parent_id_1}
             ] = data

      assert length(data) == 3
    end

    @tag authentication: [role: "user"]
    test "user without permission can not view segments rule results", %{
      conn: conn,
      swagger_schema: schema
    } do
      %{id: parent_id_1} = insert(:rule_result)
      %{id: parent_id_2} = insert(:rule_result)
      insert(:segment_result, parent_id: parent_id_1)
      insert(:segment_result, parent_id: parent_id_1)
      insert(:segment_result, parent_id: parent_id_1)
      insert(:segment_result, parent_id: parent_id_2)
      insert(:segment_result, parent_id: parent_id_2)

      assert %{"errors" => _} =
               conn
               |> get(Routes.rule_result_segment_result_path(conn, :index, parent_id_1))
               |> validate_resp_schema(schema, "SegmentResultResponse")
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "user", permissions: [:view_quality_rule]]
    test "user with permission can view segments rule results", %{
      conn: conn,
      swagger_schema: schema
    } do
      %{id: parent_id_1} = insert(:rule_result)
      %{id: parent_id_2} = insert(:rule_result)
      insert(:segment_result, parent_id: parent_id_1)
      insert(:segment_result, parent_id: parent_id_1)
      insert(:segment_result, parent_id: parent_id_1)
      insert(:segment_result, parent_id: parent_id_2)
      insert(:segment_result, parent_id: parent_id_2)

      assert %{"data" => [_ | _] = data} =
               conn
               |> get(Routes.rule_result_segment_result_path(conn, :index, parent_id_1))
               |> validate_resp_schema(schema, "SegmentResultResponse")
               |> json_response(:ok)

      assert [
               %{"parent_id" => ^parent_id_1},
               %{"parent_id" => ^parent_id_1},
               %{"parent_id" => ^parent_id_1}
             ] = data

      assert length(data) == 3
    end
  end
end
