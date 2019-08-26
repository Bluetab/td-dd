defmodule TdDqWeb.RuleResultController do
  use TdDqWeb, :controller

  alias Jason, as: JSON
  alias TdCache.ConceptCache
  alias TdCache.RuleResultCache
  alias TdCache.TaxonomyCache
  alias TdDq.Cache.RuleResultLoader
  alias TdDq.Repo
  alias TdDq.Rules

  require Logger

  @search_service Application.get_env(:td_dq, :elasticsearch)[:search_service]

  # TODO: tets this
  def upload(conn, params) do
    do_upload(params)
    send_resp(conn, :ok, "")
  rescue
    e in RuntimeError ->
      Logger.error("While uploading #{e.message}")
      send_resp(conn, :unprocessable_entity, JSON.encode!(%{error: e.message}))
  end

  defp do_upload(params) do
    Logger.info("Uploading rule results...")

    start_time = DateTime.utc_now()

    rule_results_data =
      params
      |> Map.get("rule_results")
      |> rule_results_from_csv()

    with {:ok, rule_results} <- upload_data(rule_results_data) do
      index_rule_results(rule_results_data)
      cache_rule_results(rule_results)
    end

    end_time = DateTime.utc_now()

    Logger.info("Metadata uploaded. Elapsed seconds: #{DateTime.diff(end_time, start_time)}")
  end

  defp rule_results_from_csv(%{path: path}) do
    path
    |> File.stream!()
    |> Stream.drop(1)
    |> CSV.decode!(separator: ?;)
  end

  defp upload_data(rule_results_data) do
    Repo.transaction(fn ->
      upload_in_transaction(rule_results_data)
    end)
  end

  defp index_rule_results(rule_results_data) do
    rule_results_data
    |> Enum.map(fn [implementation_key | _] ->
      Rules.get_rule_by_implementation_key(implementation_key)
    end)
    |> Enum.filter(&(not is_nil(&1)))
    |> Enum.uniq_by(fn %{id: id} -> id end)
    |> Enum.map(&@search_service.put_searchable(&1))
  end

  defp upload_in_transaction(rules_results) do
    Logger.info("Uploading rule results...")

    rules_results
    |> Enum.map(&format_date/1)
    |> Enum.map(&format_result/1)
    |> Enum.map(&with_parent_domains/1)
    |> Enum.map(&to_map/1)
    |> Enum.map(&Rules.create_rule_result/1)
  end

  defp format_date(data) do
    List.update_at(data, 1, fn x ->
      Timex.to_datetime(Timex.parse!(x, "{YYYY}-{0M}-{D}-{h24}-{m}-{s}"))
    end)
  end

  defp format_result(data) do
    List.update_at(data, 2, fn x -> String.to_integer(x) end)
  end

  defp with_parent_domains(data) do
    data ++ [get_parent_domains(data)]
  end

  defp to_map(data) do
    impl_key = Enum.at(data, 0)
    date = Enum.at(data, 1)
    result = Enum.at(data, 2)
    parent_domains = Enum.at(data, 3)

    %{implementation_key: impl_key, date: date, result: result, parent_domains: parent_domains}
  end

  # TODO: Remove this form here. Remove parent domains from rule_result table
  defp get_parent_domains(data) do
    data
    |> Enum.at(0)
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
    result_ids =
      rule_results
      |> Enum.map(&elem(&1, 1))
      |> Enum.map(&Map.get(&1, :id))

    failed_ids =
      RuleResultCache.members_failed_ids()
      |> elem(1)
      |> Enum.map(&String.to_integer(&1))

    ids = result_ids ++ failed_ids

    ids
    |> Rules.list_rule_results()
    |> Enum.group_by(&Map.take(&1, [:implementation_key, :date]))
    |> Enum.map(fn {_k, v} ->
      Enum.sort(v, &(Map.get(&1, :inserted_at) > Map.get(&2, :inserted_at)))
    end)
    |> Enum.map(&hd(&1))
    |> List.flatten()
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
