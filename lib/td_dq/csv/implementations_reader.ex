defmodule TdDq.CSV.ImplementationsReader do
  @moduledoc """
  Module to read specific implementations CSV
  """
  alias TdDq.CSV.Reader
  alias TdDq.Implementations.BulkLoad

  def read_csv(claims, stream) do
    Reader.read_csv(claims, stream, BulkLoad.required_headers(), &BulkLoad.bulk_load/2)
  end
end
