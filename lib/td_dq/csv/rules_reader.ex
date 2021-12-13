defmodule TdDq.CSV.RulesReader do
  @moduledoc """
  Module to read specific rules CSV
  """

  alias TdDq.CSV.Reader
  alias TdDq.Rules.BulkLoad

  @required_headers BulkLoad.required_headers()

  def reader_csv(claims, stream) do
    Reader.read_csv(claims, stream, @required_headers, &BulkLoad.bulk_load/2)
  end
end
