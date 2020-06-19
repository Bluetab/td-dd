defmodule TdDqWeb.RuleResultController do
  use TdDqWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias Jason, as: JSON
  alias TdCache.ConceptCache
  alias TdCache.RuleResultCache
  alias TdCache.TaxonomyCache
  alias TdDq.Cache.RuleLoader
  alias TdDq.Cache.RuleResultLoader
  alias TdDq.Repo
  alias TdDq.Rules

  require Logger

  action_fallback(TdDqWeb.FallbackController)

  def upload(conn, params) do
    case do_upload(params) do
      {:ok, _rule_results} ->
        send_resp(conn, :ok, "")

      {:error, errors} ->
        conn
        |> put_resp_content_type("application/json", "utf-8")
        |> send_resp(:unprocessable_entity, JSON.encode!(%{errors: get_errors_detail(errors)}))
    end
  rescue
    e in RuntimeError ->
      Logger.error("While uploading #{e.message}")
      send_resp(conn, :unprocessable_entity, JSON.encode!(%{error: e.message}))
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
    with user <- conn.assigns[:current_resource],
         rule_result <- Rules.get_rule_result(id),
         {:can, true} <- {:can, can?(user, delete(rule_result))},
         rule <-
           Rules.get_rule_by_implementation_key(rule_result.implementation_key, deleted: true),
         {:ok, _rule_result} <- Rules.delete_rule_result(rule_result) do
      RuleResultCache.delete(rule_result.id)
      RuleLoader.refresh([rule.id])
      send_resp(conn, :no_content, "")
    end
  end

  defp get_errors_detail(errors) do
    errors
    |> Enum.map(fn error ->
      %{changeset: changeset, row_number: row_number} = error

      changeset_errors =
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          format_error(msg, opts)
        end)

      Map.put(changeset_errors, :row_number, row_number)
    end)
  end

  defp format_error(msg, opts) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp do_upload(params) do
    Logger.info("Uploading rule results...")

    start_time = DateTime.utc_now()

    rule_results_data =
      params
      |> Map.get("rule_results")
      |> rule_results_from_csv()

    resp =
      with {:ok, rule_results} <- upload_data(rule_results_data) do
        index_rule_results(rule_results_data)
        cache_rule_results(rule_results)
        {:ok, rule_results}
      end

    end_time = DateTime.utc_now()

    Logger.info("Metadata uploaded. Elapsed seconds: #{DateTime.diff(end_time, start_time)}")
    resp
  end

  defp rule_results_from_csv(%{path: path}) do
    path
    |> File.stream!()
    |> CSV.decode!(separator: ?;, headers: true)
    |> Enum.to_list()
    |> Enum.map(fn rule_result ->
      set_quality_data(rule_result)
    end)
    |> Enum.map(fn rule_result ->
      set_quality_params(rule_result)
    end)
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

  defp upload_data(rule_results_data) do
    Repo.transaction(fn ->
      upload_in_transaction(rule_results_data)
    end)
  end

  defp index_rule_results(rule_results_data) do
    rule_results_data
    |> Enum.map(fn %{"implementation_key" => implementation_key} ->
      Rules.get_rule_by_implementation_key(implementation_key)
    end)
    |> Enum.filter(&(not is_nil(&1)))
    |> Enum.uniq_by(fn %{id: id} -> id end)
    |> Enum.map(& &1.id)
    |> RuleLoader.refresh()
  end

  defp upload_in_transaction(rules_results) do
    Logger.info("Uploading rule results...")

    {oks, errors} =
      rules_results
      |> Enum.map(&with_parent_domains/1)
      |> Enum.with_index(2)
      |> Enum.map(fn {rule_result, index} ->
        {result_code, changeset} = Rules.create_rule_result(rule_result)
        %{result_code: result_code, changeset: changeset, row_number: index}
      end)
      |> Enum.split_with(fn %{result_code: result_code} -> result_code == :ok end)

    case errors do
      [] ->
        Enum.map(oks, &Map.get(&1, :changeset))

      _ ->
        Repo.rollback(errors)
        {:error, errors}
    end
  end

  defp with_parent_domains(data) do
    Map.put(data, "parent_domains", get_parent_domains(data))
  end

  # TODO: Remove this form here. Remove parent domains from rule_result table
  defp get_parent_domains(data) do
    data
    |> Map.get("implementation_key")
    |> Rules.get_rule_implementation_by_key()
    |> case do
      nil ->
        ""

      rule_implementation ->
        case get_concept(rule_implementation) do
          nil ->
            ""

          concept ->
            concept
            |> Map.get(:domain_id)
            |> TaxonomyCache.get_parent_ids()
            |> Enum.map(&TaxonomyCache.get_name(&1))
            |> Enum.join(";")
        end
    end
  end

  defp cache_rule_results(rule_results) do
    result_ids = Enum.map(rule_results, &Map.get(&1, :id))

    failed_ids =
      RuleResultCache.members_failed_ids()
      |> elem(1)
      |> Enum.map(&String.to_integer(&1))

    ids = result_ids ++ failed_ids

    ids
    |> Rules.list_rule_results()
    |> Enum.group_by(&Map.take(&1, [:implementation_key, :date]))
    |> Enum.map(fn {_k, v} ->
      Enum.max_by(v, & &1.inserted_at, NaiveDateTime)
    end)
    |> Enum.map(&Map.get(&1, :id))
    |> RuleResultLoader.failed()
  end

  defp get_concept(rule_implementation) do
    {:ok, concept} =
      rule_implementation
      |> Repo.preload(:rule)
      |> Map.get(:rule)
      |> Map.get(:business_concept_id)
      |> ConceptCache.get()

    concept
  end

  def index(conn, _params) do
    rules_results = Rules.list_rule_results()
    render(conn, "index.json", rule_results: rules_results)
  end
end
