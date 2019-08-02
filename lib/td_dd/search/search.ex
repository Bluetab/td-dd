defmodule TdDd.Search do
  @moduledoc """
  Search Engine calls
  """

  alias Jason, as: JSON
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.ESClientApi
  alias TdDd.Repo

  require Logger

  @batch_size 100

  def put_bulk_search(:all) do
    DataStructures.list_data_structures()
    |> put_bulk_search()
  end

  def put_bulk_search(data_structures) do
    data_structures
    |> Enum.chunk_every(@batch_size)
    |> Enum.map(&bulk_index_batch/1)
  end

  defp bulk_index_batch(items) do
    time(fn ->
      items
      |> Repo.preload(
        versions: [
          :data_structure,
          parents: [:data_structure, parents: [:data_structure, :parents]]
        ]
      )
      |> ESClientApi.bulk_index_content()
    end)
  end

  defp time(fun) do
    ts = DateTime.utc_now()
    res = fun.()
    millis = DateTime.diff(DateTime.utc_now(), ts, :millisecond)
    rate = 1_000 / millis * @batch_size
    Logger.info("Indexing rate #{rate} items/s")
    res
  end

  # CREATE AND UPDATE
  def put_search(%DataStructure{} = data_structure) do
    search_fields = data_structure.__struct__.search_fields(data_structure)

    response =
      ESClientApi.index_content(
        data_structure.__struct__.index_name(data_structure),
        data_structure.id,
        search_fields |> JSON.encode!()
      )

    case response do
      {:ok, %HTTPoison.Response{status_code: status}} ->
        Logger.info("Data Structure #{data_structure.name} created/updated status #{status}")

      {:error, _error} ->
        Logger.error("ES: Error creating/updating Data Structure #{data_structure.name}")
    end
  end

  # DELETE
  def delete_search(%DataStructure{} = data_structure) do
    response = ESClientApi.delete_content("data_structure", data_structure.id)

    case response do
      {_, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("DataStructure #{data_structure.name} deleted status 200")

      {_, %HTTPoison.Response{status_code: status_code}} ->
        Logger.error(
          "ES: Error deleting data_structure #{data_structure.name} status #{status_code}"
        )

      {:error, %HTTPoison.Error{reason: :econnrefused}} ->
        Logger.error("Error connecting to ES")
    end
  end

  def search(index_name, query) do
    Logger.debug(fn -> "Query: #{inspect(query)}" end)
    response = ESClientApi.search_es(index_name, query)

    case response do
      {:ok,
       %HTTPoison.Response{
         body: %{"hits" => %{"hits" => results, "total" => total}, "aggregations" => aggregations}
       }} ->
        %{results: results, aggregations: format_search_aggegations(aggregations), total: total}

      {:ok, %HTTPoison.Response{body: error}} ->
        error
    end
  end

  def get_filters(query) do
    response = ESClientApi.search_es("data_structure", query)

    case response do
      {:ok, %HTTPoison.Response{body: %{"aggregations" => aggregations}}} ->
        aggregations
        |> format_search_aggegations()

      {:ok, %HTTPoison.Response{body: error}} ->
        error
    end
  end

  defp format_search_aggegations(aggregations) do
    aggregations
    |> Map.to_list()
    |> Enum.into(%{}, &filter_values/1)
  end

  defp filter_values({name, %{"buckets" => buckets}}) do
    {name, buckets |> Enum.map(& &1["key"])}
  end
end
