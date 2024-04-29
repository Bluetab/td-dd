defmodule TdDqWeb.RemediationController do
  use TdDqWeb, :controller

  alias TdDq.Remediations
  alias TdDq.Rules.RuleResult
  alias TdDq.Rules.RuleResults

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    TdDqWeb.SwaggerDefinitions.remediation_swagger_definitions()
  end

  swagger_path :show do
    description("Get remediation plan from the rule result it belongs to")
    produces("application/json")

    parameters do
      rule_result_id(:path, :integer, "rule result id", required: true)
    end

    response(200, "OK", Schema.ref(:RemediationResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def show(conn, %{"rule_result_id" => rule_result_id}) do
    with claims <- conn.assigns[:current_resource],
         %RuleResult{remediation: remediation} = rule_result <-
           RuleResults.get_rule_result(rule_result_id,
             preload: [:remediation, :implementation]
           ) do
      if Bodyguard.permit?(RuleResults, :manage_remediations, claims, rule_result) do
        conn
        |> put_actions(rule_result)
        |> render("show.json", remediation: remediation)
      else
        render(conn, "show.json", remediation: remediation)
      end
    end
  end

  swagger_path :create do
    description("Creates a rule result remediation plan")
    produces("application/json")

    parameters do
      rule_result_id(:path, :integer, "rule result id", required: true)
      remediation(:body, Schema.ref(:RemediationCreate), "Remediation create attrs")
    end

    response(201, "OK", Schema.ref(:RemediationResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def create(conn, %{"rule_result_id" => rule_result_id, "remediation" => remediation_params}) do
    with claims <- conn.assigns[:current_resource],
         %RuleResult{} = rule_result <-
           RuleResults.get_rule_result(rule_result_id, preload: [:implementation]),
         :ok <- Bodyguard.permit(RuleResults, :manage_remediations, claims, rule_result),
         {:ok, %{remediation: remediation}} <-
           Remediations.create_remediation(rule_result_id, remediation_params, claims) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.rule_result_remediation_path(conn, :show, remediation)
      )
      |> put_actions(rule_result)
      |> render("show.json", remediation: remediation)
    end
  end

  swagger_path :update do
    description("Update rule result remediation plan")
    produces("application/json")

    parameters do
      rule_result_id(:path, :integer, "rule result id", required: true)
      remediation(:body, Schema.ref(:RemediationUpdate), "Remediation plan update attrs")
    end

    response(201, "OK", Schema.ref(:RemediationResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{"rule_result_id" => rule_result_id, "remediation" => remediation_params}) do
    with claims <- conn.assigns[:current_resource],
         %RuleResult{remediation: remediation} = rule_result <-
           RuleResults.get_rule_result(rule_result_id, preload: [:remediation, :implementation]),
         :ok <- Bodyguard.permit(RuleResults, :manage_remediations, claims, rule_result),
         {:ok, remediation} <-
           Remediations.update_remediation(remediation, remediation_params, claims) do
      conn
      |> put_actions(rule_result)
      |> render("show.json", remediation: remediation)
    end
  end

  swagger_path :delete do
    description("Delete a rule result remediation plan")
    produces("application/json")

    parameters do
      rule_result_id(:path, :integer, "rule result id", required: true)
    end

    response(204, "No Content")
    response(403, "Forbidden")
    response(404, "Not found")
    response(422, "Unprocessable Entity")
  end

  def delete(conn, %{"rule_result_id" => rule_result_id}) do
    with claims <- conn.assigns[:current_resource],
         %RuleResult{remediation: remediation} = rule_result <-
           RuleResults.get_rule_result(rule_result_id, preload: [:remediation, :implementation]),
         true <- not is_nil(remediation) || nil,
         :ok <- Bodyguard.permit(RuleResults, :manage_remediations, claims, rule_result),
         {:ok, _remediation} <- Remediations.delete_remediation(remediation) do
      send_resp(conn, :no_content, "")
    end
  end

  defp put_actions(conn, %{id: rule_result_id}) do
    actions = %{
      "create" => %{
        href: Routes.rule_result_remediation_path(conn, :create, rule_result_id),
        method: "POST"
      },
      "update" => %{
        href: Routes.rule_result_remediation_path(conn, :update, rule_result_id),
        method: "PATCH"
      },
      "delete" => %{
        href: Routes.rule_result_remediation_path(conn, :delete, rule_result_id),
        method: "DELETE"
      },
      "show" => %{
        href: Routes.rule_result_remediation_path(conn, :show, rule_result_id),
        method: "GET"
      }
    }

    assign(conn, :actions, actions)
  end
end
