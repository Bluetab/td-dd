defmodule TdDqWeb.RemediationController do
  use TdDqWeb, :controller

  alias TdDq.Remediations
  alias TdDq.Remediations.Remediation
  alias TdDq.Rules.RuleResult
  alias TdDq.Rules.RuleResults


  action_fallback(TdDqWeb.FallbackController)


  @spec show(any, map) :: nil | [%{optional(atom) => any}] | %{optional(atom) => any}
  def show(conn, %{"rule_result_id" => rule_result_id}) do
    #claims = conn.assigns[:current_resource]
    IO.puts("REMEDIATION_CONTROLLER SHOW")

    with %Remediation{} = remediation <- Remediations.get_by_rule_result_id(String.to_integer(rule_result_id)) do
      render(conn, "show.json", remediation: remediation)
    end
  end

  def create(conn, %{"rule_result_id" => rule_result_id, "remediation" => remediation_params}) do
    with _claims <- conn.assigns[:current_resource],
         {:ok, remediation} <- Remediations.create_remediation(rule_result_id, remediation_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.rule_result_remediation_path(conn, :show, remediation))
      |> render("show.json", remediation: remediation)
    end
  end

  def update(conn, %{"rule_result_id" => rule_result_id, "remediation" => remediation_params}) do
    claims = conn.assigns[:current_resource]

    IO.puts("*****************UPDATE")

    with _claims <- conn.assigns[:current_resource],
         %Remediation{} = remediation <- Remediations.get_by_rule_result_id(rule_result_id),
         {:ok, remediation} <- Remediations.update_remediation(remediation, remediation_params) do

      IO.puts("WITH")
      render(conn, "show.json", remediation: remediation)
    end

    # with {:can, true} <- {:can, can?(claims, update(%Source{}))},
    #      %Source{} = source <- Sources.get_source(external_id),
    #      {:ok, %Source{} = source} <- Sources.update_source(source, source_params) do
    #   render(conn, "show.json", source: source)
    # end
  end

end
