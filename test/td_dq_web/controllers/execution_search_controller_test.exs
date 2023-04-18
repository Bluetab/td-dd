defmodule TdDqWeb.ExecutionSearchControllerTest do
  use TdDqWeb.ConnCase

  setup do
    execution =
      insert(:execution,
        group: build(:execution_group),
        implementation: build(:implementation, rule: build(:rule))
      )

    [execution: execution]
  end

  describe "POST /api/executions/search" do
    @tag authentication: [role: "service"]
    test "service account can search executions", %{conn: conn} do
      params = %{"foo" => "bar"}

      assert %{"data" => [_]} =
               conn
               |> post(Routes.execution_search_path(conn, :create), params)
               |> json_response(:ok)
    end

    @tag authentication: [role: "service"]
    test "returns pending executions by implementation source", %{conn: conn} do
      %{external_id: source_external_id} = source = insert(:source)
      dataset_structure = insert(:data_structure, source: source)

      %{id: implementation_ref_id} =
        implementation_ref =
        insert(:implementation,
          status: :versioned,
          version: 1
        )

      implementation =
        insert(:implementation,
          status: :published,
          version: 2,
          implementation_ref: implementation_ref_id
        )

      insert(:implementation_structure,
        implementation: implementation_ref,
        data_structure: dataset_structure
      )

      %{id: execution_id} = insert(:execution, implementation: implementation)

      params = %{
        sources: [source_external_id],
        status: "pending"
      }

      assert %{"data" => [%{"id" => ^execution_id}]} =
               conn
               |> post(Routes.execution_search_path(conn, :create), params)
               |> json_response(:ok)
    end
  end
end
