defmodule TdDq.CSV.RulesReader do
  @moduledoc """
  Module to read specific rules CSV
  """

  alias TdDq.CSV.Reader
  alias TdDq.Rules.BulkLoad

  @required_headers BulkLoad.required_headers()

  def reader_csv(claims, stream) do
    case Reader.parse_csv(stream, @required_headers) do
      {:ok, parsed_csv} -> BulkLoad.bulk_load(parsed_csv, claims)
      error -> error
    end
  end
end
