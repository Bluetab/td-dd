defmodule Truedat.Search.Indexer do
  @moduledoc """
  Manages elasticsearch indices
  """

  require Logger

  alias Elasticsearch.Cluster.Config
  alias Elasticsearch.Index
  alias Elasticsearch.Index.Bulk

  def maybe_hot_swap({:ok, _put_template_result}, cluster, alias_name) do
    Logger.info("Starting reindex using hot_swap...")
    hot_swap(cluster, alias_name)
  end

  def maybe_hot_swap({:error, _error} = put_template_error, _cluster, _alias_name) do
    Logger.warn("Index template update errors, will not reindex")
    put_template_error
  end

  # Modified from Elasticsearch.Index.hot_swap for better logging and
  # error handling
  def hot_swap(cluster, alias) do
    alias = alias_to_atom(alias)
    name = Index.build_name(alias)
    config = Config.get(cluster)
    %{settings: settings} = index_config = config[:indexes][alias]

    with :ok <- Index.create_from_settings(config, name, settings),
         :ok <- Bulk.upload(config, name, index_config),
         :ok <- Index.alias(config, name, to_string(alias)),
         :ok <- Index.clean_starting_with(config, to_string(alias), 2),
         :ok <- Index.refresh(config, name) do
      Logger.info("Hot swap successful, finished reindexing, pointing alias #{alias} -> #{name}")
      {:ok, name}
    else
      error ->
        log_hot_swap_errors(name, error)
        Logger.warn("Removing incomplete index #{name}...")
        delete_existing_index(cluster, name)
        {:error, name}
    end
  end

  defp alias_to_atom(atom) when is_atom(atom), do: atom
  defp alias_to_atom(str) when is_binary(str), do: String.to_existing_atom(str)

  def put_template(template, cluster, name) do
    case Elasticsearch.put(cluster, "/_template/#{name}", template,
           params: %{"include_type_name" => "false"}
         ) do
      {:ok, result} = successful_update ->
        Logger.info("Index #{name} template update successful: #{inspect(result)}")
        successful_update

      {:error, %Elasticsearch.Exception{message: message}} = failed_update ->
        Logger.warn("Index #{name} template update failed: #{message}")
        failed_update
    end
  end

  def alias_exists?(cluster, name) do
    case Elasticsearch.head(cluster, "/_alias/#{name}") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  def delete_existing_index(cluster, name) do
    case Elasticsearch.delete(cluster, "/#{name}") do
      {:ok, result} = successful_deletion ->
        Logger.info("Successfully deleted index #{name}: #{inspect(result)}")
        successful_deletion

      {:error, %{status: 404} = not_found} ->
        Logger.warn("Index #{name} does not exist, nothing to delete.")
        {:ok, not_found}

      {:error, e} = failed_deletion when Kernel.is_exception(e) ->
        Logger.error("Failed to delete index #{name}, message: #{Exception.message(e)}")
        failed_deletion

      error ->
        Logger.error("Failed to delete index #{name}, message: #{inspect(error)}")
        error
    end
  end

  def log_bulk_post(index, {:ok, %{"errors" => false, "items" => items, "took" => took}}, _action) do
    Logger.info("#{index}: bulk indexed #{Enum.count(items)} documents (took=#{took})")
  end

  def log_bulk_post(index, {:ok, %{"errors" => true, "items" => items}}, action) do
    items
    |> Enum.filter(& &1[action]["error"])
    |> log_bulk_post_items_errors(index, action)
  end

  def log_bulk_post(index, {:error, error}, _action) do
    Logger.error("#{index}: bulk indexing encountered errors #{inspect(error)}")
  end

  def log_bulk_post(index, error, _action) do
    Logger.error("#{index}: bulk indexing encountered errors #{inspect(error)}")
  end

  def log_bulk_post_items_errors(errors, index, action) do
    errors
    |> Enum.map(&"#{info_document_id(&1, action)}: #{message(&1, action)}\n")
    |> Kernel.then(fn messages ->
      ["#{index}: bulk indexing encountered #{pluralize(errors)}:\n" | messages]
    end)
    |> Logger.error()
  end

  def log_hot_swap_errors(index, {:error, [_ | _] = exceptions}) do
    exceptions
    |> Enum.map(&"#{message(&1)}\n")
    |> Kernel.then(fn messages ->
      ["New index #{index} build finished with #{pluralize(exceptions)}:\n" | messages]
    end)
    |> Logger.error()
  end

  def log_hot_swap_errors(index, {:error, e}) do
    Logger.error("New index #{index} build finished with an error:\n #{message(e)}")
  end

  def log_hot_swap_errors(index, e) do
    Logger.error("New index #{index} build finished with an error:\n #{message(e)}")
  end

  def pluralize([_e]) do
    "an error"
  end

  def pluralize([_ | _] = exceptions) do
    "#{Enum.count(exceptions)} errors"
  end

  defp message(%Elasticsearch.Exception{} = e) do
    "#{info_document_id(e)}#{Exception.message(e)}"
  end

  defp message(e) when Kernel.is_exception(e) do
    Exception.message(e)
  end

  defp message(e) do
    "#{inspect(e)}"
  end

  defp message(item, action) do
    item[action]["error"]["reason"]
  end

  defp info_document_id(%Elasticsearch.Exception{raw: %{"_id" => id}}),
    do: "Document ID #{id}: "

  defp info_document_id(_), do: ""

  defp info_document_id(item, action) do
    "Document ID #{item[action]["_id"]}"
  end
end
