defmodule TdDqWeb.RuleResultController do
  use TdDqWeb, :controller

  alias TdDq.Rules.RuleResults
  alias TdDq.Rules.RuleResults.BulkLoad

  require Logger

  action_fallback(TdDqWeb.FallbackController)

  def create(conn, params) do
    with claims <- conn.assigns[:current_resource],
         %{"rule_results" => rule_results_file} <- params,
         :ok <- Bodyguard.permit(RuleResults, :upload, claims),
         rule_results_data <- rule_results_from_csv(rule_results_file),
         {:ok, _} <- BulkLoad.bulk_load(rule_results_data) do
      send_resp(conn, :ok, "")
    end
  end

  def delete(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         rule_result <- RuleResults.get_rule_result(id),
         :ok <- Bodyguard.permit(RuleResults, :delete, claims, rule_result),
         {:ok, _rule_result} <- RuleResults.delete_rule_result(rule_result) do
      send_resp(conn, :no_content, "")
    end
  end

  def show(conn, %{"id" => id} = _params) do
    with claims <- conn.assigns[:current_resource],
         rule_result <- RuleResults.get_rule_result(id),
         :ok <- Bodyguard.permit(RuleResults, :view, claims, rule_result) do
      render(conn, "show.json", rule_result: rule_result)
    end
  end

  def index(conn, params) do
    with claims <- conn.assigns[:current_resource],
         :ok <- Bodyguard.permit(RuleResults, :list_rule_results, claims),
         {:ok, %{all: rule_results, total: total}} <-
           RuleResults.list_rule_results_paginate(params) do
      conn
      |> put_resp_header("x-total-count", "#{total}")
      |> render("index.json", rule_results: rule_results)
    end
  end

  defp rule_results_from_csv(%{path: path}) do
    path
    |> File.stream!()
    |> CSV.decode!(separator: ?;, headers: true)
    |> Enum.to_list()
    |> Enum.map(&set_quality_params/1)
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
end
