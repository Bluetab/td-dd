defmodule TdCx.ElasticsearchMock do
  @moduledoc """
  A mock for elasticsearch supporting Business Glossary queries.
  """

  @behaviour Elasticsearch.API

  alias HTTPoison.Response
  alias Jason, as: JSON
  alias TdCx.Repo
  alias TdCx.Sources.Jobs

  require Logger

  @impl true
  def request(_config, :head, "/_alias/jobs", _data, _opts) do
    {:ok, %Response{status_code: 200, body: []}}
  end

  @impl true
  def request(_config, :get, "/_cat/indices?format=json", _data, _opts) do
    {:ok, %Response{status_code: 200, body: []}}
  end

  @impl true
  def request(_config, :put, "/_template/jobs", _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{}}}
  end

  @impl true
  def request(_config, :post, "/_aliases", _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{}}}
  end

  @impl true
  def request(_config, _method, "/jobs-" <> _suffix, _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{}}}
  end

  @impl true
  def request(_config, :post, "/jobs/_doc/_bulk", _data, _opts) do
    body = %{"took" => 10, "items" => [], "errors" => false}
    {:ok, %Response{status_code: 200, body: body}}
  end

  @impl true
  def request(_config, :post, "/jobs/_search", _data, _opts) do
    Jobs.list_jobs()
    |> Repo.preload([:source, :events])
    |> Enum.map(&with_source/1)
    |> Enum.map(&Jobs.with_metrics/1)
    |> Enum.map(&Map.delete(&1, :__meta__))
    |> Enum.map(&Map.from_struct/1)
    |> search_results()
  end

  @impl true
  def request(_config, :delete, "/jobs/_doc/" <> _id, _data, _opts) do
    {:ok, %Response{status_code: 200, body: %{result: "deleted"}}}
  end

  @impl true
  def request(_config, method, url, data, _opts) do
    Logger.warn("#{method} #{url} #{JSON.encode!(data)}")
    search_results([])
  end

  defp search_results(hits, query \\ %{}) do
    results =
      hits
      |> Enum.map(&%{_source: &1})
      |> JSON.encode!()
      |> JSON.decode!()

    body = %{
      "hits" => %{"hits" => results, "total" => Enum.count(results)},
      "aggregations" => %{},
      "query" => query
    }

    {:ok, %Response{status_code: 200, body: body}}
  end

  defp with_source(%{source: source} = job) do
    Map.put(job, :source, Map.take(source, [:external_id, :type]))
  end
end
