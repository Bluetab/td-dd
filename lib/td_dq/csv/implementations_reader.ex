defmodule TdDq.CSV.ImplementationsReader do
  @moduledoc """
  Module to read specific implementations CSV
  """
  alias TdDq.CSV.Reader
  alias TdDq.Implementations.BulkLoad

  @required_headers BulkLoad.required_headers()

  def read_csv(claims, stream, auto_publish, lang) do
    case Reader.parse_csv(stream, @required_headers) do
      {:ok, parsed_csv} -> BulkLoad.bulk_load(parsed_csv, claims, auto_publish, lang)
      error -> error
    end
  end
end
