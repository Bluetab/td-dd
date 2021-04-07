defmodule TdCx.Sources.Query do
  @moduledoc """
  Helper module to manipulate queries.
  """

  def add_query_wildcard(query) do
    case String.last(query) do
      nil -> query
      "\"" -> query
      ")" -> query
      " " -> query
      _ -> "#{query}*"
    end
  end
end
