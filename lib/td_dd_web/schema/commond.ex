defmodule TdDdWeb.Schema.Commond do
  @moduledoc """
  Absinthe schema definitions for commond objects
  """

  use Absinthe.Schema.Notation

  object :page_info do
    field :end_cursor, :cursor
    field :start_cursor, :cursor
    field :has_next_page, non_null(:boolean)
    field :has_previous_page, non_null(:boolean)
  end

end
