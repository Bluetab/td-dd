defmodule TdDqWeb.RuleResultController do
  use TdDqWeb, :controller

  alias Ecto.Adapters.SQL
  alias Jason, as: JSON
  alias TdCache.ConceptCache
  alias TdCache.TaxonomyCache
  alias TdDq.Repo
  alias TdDq.Rules

  require Logger

  @search_service Application.get_env(:td_dq, :elasticsearch)[:search_service]

  @rules_results_query ~S"""
    INSERT INTO rule_results ("implementation_key", "date", "result", parent_domains, inserted_at, updated_at)
    VALUES ($1, $2, $3, $4, $5, $5)
  """
  @rule_results_param "rule_results"

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
      |> Map.get(@rule_results_param)
      |> rule_results_from_csv()

    with {:ok, _} <- upload_data(rule_results_data) do
      index_rule_results(rule_results_data)
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
    |> Enum.each(fn data ->
      data =
        List.update_at(data, 1, fn x ->
          Timex.to_datetime(Timex.parse!(x, "{YYYY}-{0M}-{D}-{h24}-{m}-{s}"))
        end)

      data = List.update_at(data, 2, fn x -> String.to_integer(x) end)
      data = data ++ [get_parent_domains(data), DateTime.utc_now()]
      SQL.query!(Repo, @rules_results_query, data)
    end)
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
