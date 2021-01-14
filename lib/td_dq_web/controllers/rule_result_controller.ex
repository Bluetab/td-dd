defmodule TdDqWeb.RuleResultController do
  use TdDqWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDq.Rules
  alias TdDq.Rules.RuleResults

  require Logger

  action_fallback(TdDqWeb.FallbackController)

  def upload(conn, params) do
    with %{"rule_results" => rule_results_file} <- params,
         rule_results_data <- rule_results_from_csv(rule_results_file),
         {:ok, _} <- RuleResults.bulk_load(rule_results_data) do
      send_resp(conn, :ok, "")
    end
  end

  swagger_path :delete do
    description("Delete Rule Result")
    produces("application/json")

    parameters do
      id(:path, :integer, "Rule Result ID", required: true)
    end

    response(422, "Unprocessable Entity")
    response(500, "Internal Server Error")
  end

  def delete(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         rule_result <- RuleResults.get_rule_result(id),
         {:can, true} <- {:can, can?(claims, delete(rule_result))},
         rule <-
           Rules.get_rule_by_implementation_key(rule_result.implementation_key, deleted: true),
         {:ok, _rule_result} <- RuleResults.delete_rule_result(rule_result, rule) do
      send_resp(conn, :no_content, "")
    end
  end

  defp rule_results_from_csv(%{path: path}) do
    path
    |> File.stream!()
    |> CSV.decode!(separator: ?;, headers: true)
    |> Enum.to_list()
    |> Enum.map(&set_quality_data/1)
    |> Enum.map(&set_quality_params/1)
  end

  defp set_quality_data(%{"records" => records, "errors" => errors} = rule_result) do
    Map.put(
      rule_result,
      "result",
      calculate_quality(String.to_integer(records), String.to_integer(errors))
    )
  end

  defp set_quality_data(rule_result) do
    rule_result
  end

  defp set_quality_params(rule_result) do
    params =
      rule_result
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, "m:") end)
      |> Enum.reduce(%{}, &put_params/2)

    case params === %{} do
      true -> rule_result
      _ -> Map.put(rule_result, "params", params)
    end
  end

  defp put_params({_k, ""}, acc) do
    acc
  end

  defp put_params({k, v}, acc) do
    k_suffix = String.replace_leading(k, "m:", "")
    Map.put(acc, k_suffix, v)
  end

  defp calculate_quality(0, _errors) do
    0
  end

  defp calculate_quality(records, errors) do
    abs((records - errors) / records) * 100
  end

  def index(conn, _params) do
    rule_results = RuleResults.list_rule_results()
    render(conn, "index.json", rule_results: rule_results)
  end
end
