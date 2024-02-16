defmodule TdDqWeb.ImplementationResultController do
  use TdDqWeb, :controller

  alias TdDq.Implementations
  alias TdDq.Rules.RuleResults
  alias TdDqWeb.RuleResultView

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.rule_result_swagger_definitions()
  end

  swagger_path :create do
    description("Creates a RuleResult")
    produces("application/json")

    parameters do
      result(:body, Schema.ref(:RuleResultCreate), "Result create attrs")
    end

    response(201, "Created", Schema.ref(:RuleResultResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"implementation_id" => key, "rule_result" => params}) do
    claims = conn.assigns[:current_resource]

    with {:ok, implementation} <- Implementations.get_published_implementation_by_key(key),
         :ok <- Bodyguard.permit(Implementations, :manage_rule_results, claims, implementation),
         {:ok, %{result: %{id: id} = result, segments: segments}} <-
           RuleResults.create_rule_result(implementation, params) do
      result = Map.put(result, :segments_inserted, length(segments))

      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.rule_result_path(conn, :show, id))
      |> put_view(RuleResultView)
      |> render("show.json", rule_result: result)
    end
  end
end
