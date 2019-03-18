defmodule TdDq.Search do
  require Logger

  alias TdDq.ESClientApi

  @moduledoc """
    Search Engine calls
  """

  def put_bulk_search(items) do
    items
    |> Enum.chunk_every(100)
    |> Enum.map(&ESClientApi.bulk_index_content/1)
  end

  # CREATE AND UPDATE
  def put_searchable(searchable) do
    search_fields = searchable.__struct__.search_fields(searchable)
    index_name = searchable.__struct__.index_name()

    response =
      ESClientApi.index_content(
        index_name,
        searchable.id,
        search_fields |> Poison.encode!()
      )

    case response do
      {:ok, %HTTPoison.Response{status_code: _}} ->
        Logger.info("Item on #{index_name} was created/updated")

      {:error, _error} ->
        Logger.error("ES: Error creating/updating Item on #{index_name}")
    end
  end

  # DELETE
  def delete_searchable(searchable) do
    index_name = searchable.__struct__.index_name()
    response = ESClientApi.delete_content(index_name, searchable.id)

    case response do
      {_, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("Item on #{index_name} deleted status 200")

      {_, %HTTPoison.Response{status_code: status_code}} ->
        Logger.error(
          "ES: Error deleting item on #{index_name} status #{status_code}"
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

  defp format_search_aggegations(aggregations) do
    aggregations
    |> Map.to_list()
    |> Enum.into(%{}, &filter_values/1)
  end

  defp filter_values({name, %{"buckets" => buckets}}) do
    {name, buckets |> Enum.map(& &1["key"])}
  end
end
