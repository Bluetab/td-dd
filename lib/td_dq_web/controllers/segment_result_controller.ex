defmodule TdDqWeb.SegmentResultController do
  use TdDqWeb, :controller

  alias TdDq.Rules.RuleResults

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.segment_results_swagger_definitions()
  end

  swagger_path :index do
    description("List Segment Results")
    response(200, "OK", Schema.ref(:SegmentResultResponse))
  end

  def index(conn, %{"rule_result_id" => parent_id}) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(RuleResults, :view, claims),
         segment_results <- RuleResults.list_segment_results_by_parent_id(parent_id) do
      render(conn, "index.json", segment_results: segment_results)
    end
  end

  def index(conn, params) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(RuleResults, :view, claims),
         {:ok, %{all: segment_results, total: total}} <- RuleResults.list_segment_results(params) do
      conn
      |> put_resp_header("x-total-count", "#{total}")
      |> render("index.json", segment_results: segment_results)
    end
  end
end
