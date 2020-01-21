defmodule TdCx.Repo do
  use Ecto.Repo,
    otp_app: :td_cx,
    adapter: Ecto.Adapters.Postgres

  alias TdCx.Repo

  @doc """
  Perform preloading on chunks of a stream.
  """
  def stream_preload(stream, size, preloads, opts \\ []) do
    stream
    |> Stream.chunk_every(size)
    |> Stream.flat_map(&Repo.preload(&1, preloads, opts))
  end
end
