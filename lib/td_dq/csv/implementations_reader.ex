defmodule TdDq.CSV.ImplementationsReader do
  @moduledoc """
  Module to read specific implementations CSV
  """
  alias TdDq.CSV.Reader
  alias TdDq.Implementations.BulkLoad

  @required_headers BulkLoad.required_headers()

  def read_csv(claims, stream) do
    Reader.read_csv(claims, stream, @required_headers, &BulkLoad.bulk_load/2)
  end
end
