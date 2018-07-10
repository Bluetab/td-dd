defmodule TdDd.ESClientApi do
  use HTTPoison.Base
  require Logger
  alias Poison, as: JSON

  @moduledoc false

  @doc """
  Loads all index configuration into elasticsearch
  """
  # def create_indexes do
  #   json = File.read!(Path.join(:code.priv_dir(:td_dd), "static/indexes.json"))
  #   json_decode = json |> Poison.decode!()
  #
  #   Enum.map(json_decode, fn x ->
  #     index_name = x |> Map.keys() |> List.first()
  #     mapping = x[index_name] |> Poison.encode!()
  #     %HTTPoison.Response{body: _response, status_code: status} = put!(index_name, mapping)
  #     Logger.info("Create index #{index_name} status #{status}")
  #   end)
  # end

  def bulk_index_content(items) do
    json_bulk_data =
      items
      |> Enum.map(fn item ->
        [build_bulk_metadata(item.__struct__.index_name, item), build_bulk_doc(item)]
      end)
      |> List.flatten()
      |> Enum.join("\n")
      |> IO.inspect()
    post("_bulk", json_bulk_data <> "\n")
  end

  defp build_bulk_doc(item) do
    search_fields = item.__struct__.search_fields(item)
    "#{search_fields |> Poison.encode!()}"
  end

  defp build_bulk_metadata(index_name, item) do
    ~s({"index": {"_id": #{item.id}, "_type": "#{get_type_name()}", "_index": "#{index_name}"}})
  end

  # def index_content(index_name, id, body) do
  #   put(get_search_path(index_name, id), body)
  # end
  #
  # def delete_content(index_name, id) do
  #   delete(get_search_path(index_name, id))
  # end
  #
  # def search_es(index_name, query) do
  #   post("#{index_name}/" <> "_search/", query |> JSON.encode!())
  # end
  #
  defp get_type_name do
    Application.get_env(:td_dd, :elasticsearch)[:type_name]
  end

  # defp get_search_path(index_name, id) do
  #   type_name = get_type_name()
  #   "#{index_name}/" <> "#{type_name}/" <> "#{id}"
  # end

  @doc """
  Deletes all indexes in elasticsearch
  """
  # def delete_indexes(options \\ []) do
  #   json = File.read!(Path.join(:code.priv_dir(:td_dd), "static/indexes.json"))
  #   json_decode = json |> Poison.decode!()
  #
  #   Enum.map(json_decode, fn x ->
  #     index_name = x |> Map.keys() |> List.first()
  #     %HTTPoison.Response{body: _response, status_code: status} = delete!(index_name, options)
  #     Logger.info("Delete index #{index_name} status #{status}")
  #   end)
  # end

  @doc """
    Concatenates elasticsearch path at the beggining of HTTPoison requests
  """
  def process_url(path) do
    es_config = Application.get_env(:td_dd, :elasticsearch)
    "#{es_config[:es_host]}:#{es_config[:es_port]}/" <> path
  end

  @doc """
    Decodes response body
  """
  def process_response_body(body) do
    body
    |> Poison.decode!()
  end

  @doc """
    Adds requests headers
  """
  def process_request_headers(_headers) do
    headers = [{"Content-Type", "application/json"}]
    headers
  end
end
