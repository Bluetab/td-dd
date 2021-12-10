defmodule TdDq.CSV.ImplementationsReader do
  alias TdDq.Implementations.BulkLoad

  def read_csv(claims, stream) do
    TdDq.CSV.Reader.read_csv(claims, stream, BulkLoad.required_headers(), &BulkLoad.bulk_load/2)
  end
end
