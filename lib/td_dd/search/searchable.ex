defmodule TdDd.Searchable do

  @moduledoc """
   Defines functions that must be implemented when having Searchable behaviour
  """

  @callback search_fields(any) :: any
  @callback index_name() :: any
end
