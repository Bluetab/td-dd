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
end
