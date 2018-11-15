defmodule TdDd.Search do
  require Logger
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.ESClientApi

  @moduledoc """
    Search Engine calls
  """

  def put_bulk_search(:data_structure) do
    data_structures = DataStructures.list_data_structures()
    ESClientApi.bulk_index_content(data_structures)
  end

  # CREATE AND UPDATE
  def put_search(%DataStructure{} = data_structure) do
    search_fields = data_structure.__struct__.search_fields(data_structure)

    response =
      ESClientApi.index_content(
        data_structure.__struct__.index_name(data_structure),
        data_structure.id,
        search_fields |> Poison.encode!()
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
    response = ESClientApi.search_es(index_name, query)

    case response do
      {:ok, %HTTPoison.Response{body: %{"hits" => %{"hits" => results, "total" => total}}}} ->
        %{results: results, total: total}

      {:ok, %HTTPoison.Response{body: error}} ->
        error
    end
  end

  def get_filters(query) do
    response = ESClientApi.search_es("data_structure", query)

    case response do
      {:ok, %HTTPoison.Response{body: %{"aggregations" => aggregations}}} ->
        aggregations
        |> Map.to_list()
        |> Enum.map(&filter_values/1)
        |> Enum.into(%{})

      {:ok, %HTTPoison.Response{body: error}} ->
        error
    end
  end

  defp filter_values({name, %{"buckets" => buckets}}) do
    {name, buckets |> Enum.map(& &1["key"])}
  end
end
