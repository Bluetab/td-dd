defmodule TdDd.ESClientApi do
  use HTTPoison.Base

  alias Jason, as: JSON
  alias TdDd.Search.BulkRequest

  require Logger

  @moduledoc false

  def bulk_index_content(items) do
    json_bulk_data =
      items
      |> Enum.map(&BulkRequest.new/1)
      |> Enum.join("\n")

    post("_bulk", json_bulk_data <> "\n")
  end

  def index_content(index_name, id, body) do
    put("#{index_name}/doc/#{id}", body)
  end

  def delete_content(index_name, id) do
    delete("#{index_name}/doc/#{id}")
  end

  def search_es(index_name, query) do
    post("#{index_name}/_search/", query |> JSON.encode!())
  end

  @doc """
  Concatenates elasticsearch path at the beggining of HTTPoison requests
  """
  def process_url(path) do
    es_config = Application.get_env(:td_dd, :elasticsearch)
    "#{es_config[:es_host]}:#{es_config[:es_port]}/" <> path
  end

  @doc """
  Set default request options (increase timeout for receiving HTTP response)
  """
  def process_request_options(options) do
    [recv_timeout: 20_000]
    |> Keyword.merge(options)
  end

  @doc """
  Decodes response body
  """
  def process_response_body(body) do
    body
    |> JSON.decode!()
  end

  @doc """
  Adds requests headers
  """
  def process_request_headers(_headers) do
    headers = [{"Content-Type", "application/json"}]
    headers
  end
end
