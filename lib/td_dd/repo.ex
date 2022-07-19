defmodule TdDd.Repo do
  use Ecto.Repo,
    otp_app: :td_dd,
    adapter: Ecto.Adapters.Postgres

  alias Ecto.Adapters.SQL

  require Logger

  @owned_relations [
    "classifier_filters",
    "classifier_rules",
    "classifiers",
    "configurations",
    "data_structure_relations",
    "data_structure_types",
    "data_structure_versions",
    "data_structures",
    "edges",
    "events",
    "execution_groups",
    "executions",
    "graphs",
    "jobs",
    "nodes",
    "profile_events",
    "profile_execution_groups",
    "profile_executions",
    "profiles",
    "relation_types",
    "rule_implementations",
    "rule_results",
    "rules",
    "sources",
    "structure_classifications",
    "structure_metadata",
    "systems",
    "tags",
    "unit_events",
    "units",
    "user_search_filters"
  ]

  @doc """
  Perform preloading on chunks of a stream.
  """
  def stream_preload(stream, size, preloads, opts \\ []) do
    stream
    |> Stream.chunk_every(size)
    |> Stream.flat_map(&__MODULE__.preload(&1, preloads, opts))
  end

  @doc """
  Inserts all entries into the repository using `Ecto.Repo.insert_all/3`,
  batching entries into chunks whose size is specified by the `chunk_size`
  option.
  """
  def chunk_insert_all(schema_or_source, entries, opts \\ [])

  def chunk_insert_all(_, [], opts) do
    case Keyword.get(opts, :returning, false) do
      false -> {0, nil}
      _ -> {0, []}
    end
  end

  def chunk_insert_all(schema_or_source, entries, opts) do
    {chunk_size, opts} = Keyword.pop!(opts, :chunk_size)

    entries
    |> Enum.chunk_every(chunk_size)
    |> Enum.map(fn chunk ->
      insert_all(schema_or_source, chunk, opts)
    end)
    |> Enum.reduce(fn
      {c1, nil}, {c2, nil} -> {c1 + c2, nil}
      {c1, r1}, {c2, r2} -> {c1 + c2, r1 ++ r2}
    end)
  end

  def vacuum(target) when is_binary(target) do
    target
    |> String.split()
    |> vacuum()
  end

  def vacuum([_ | _] = table_names) do
    table_names
    |> Enum.uniq()
    |> Enum.split_with(&valid_name?/1)
    |> case do
      {[_ | _] = good, []} ->
        good
        |> Enum.join(", ")
        |> do_vacuum()

      _ ->
        {:error, :invalid_name}
    end
  end

  defp do_vacuum(targets) when is_binary(targets) do
    sql = "VACUUM (VERBOSE, ANALYZE) " <> targets

    __MODULE__
    |> SQL.query(sql)
    |> log_messages()
  end

  defp log_messages({:ok, %{messages: messages}}) when is_list(messages) do
    Enum.each(messages, fn
      %{severity: "WARNING", message: message} -> Logger.warn("#{message}")
      %{severity: severity, message: message} -> Logger.info("#{severity} #{message}")
      _ -> :ok
    end)
  end

  defp log_messages({:error, %{postgres: %{message: message}}}) when is_binary(message) do
    Logger.warn(message)
  end

  defp log_messages({:error, %{message: message}}) when is_binary(message) do
    Logger.error(message)
  end

  defp log_messages(error) do
    Logger.error("Unexpected result #{inspect(error)}")
  end

  defp valid_name?(value), do: value in @owned_relations
end
