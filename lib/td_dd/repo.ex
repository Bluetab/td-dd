defmodule TdDd.Repo do
  use Ecto.Repo,
    otp_app: :td_dd,
    adapter: Ecto.Adapters.Postgres

  alias TdDd.Repo

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end

  @doc """
  Perform preloading on chunks of a stream.
  """
  def stream_preload(stream, size, preloads, opts \\ []) do
    stream
    |> Stream.chunk_every(size)
    |> Stream.flat_map(&Repo.preload(&1, preloads, opts))
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
end
