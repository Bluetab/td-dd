defmodule TdDdWeb.Resolvers.Utils.CursorPagination do
  @moduledoc "Utility functions for cursor pagination"

  def put_order_by(args, %{after: _}), do: Map.put(args, :order_by, :id)
  def put_order_by(args, %{last: _}), do: Map.put(args, :order_by, desc: :id)
  def put_order_by(args, %{}), do: Map.put(args, :order_by, :id)

  def read_page(%{count: 0}, _fun) do
    %{
      total_count: 0,
      page: [],
      page_info: %{
        start_cursor: nil,
        end_cursor: nil,
        has_next_page: false,
        has_previous_page: false
      }
    }
  end

  def read_page(%{count: count, min_id: min_id, max_id: max_id}, fun) do
    page = fun.()

    {start_cursor, end_cursor} =
      page
      |> Enum.map(& &1.id)
      |> Enum.min_max(fn -> {0, nil} end)

    %{
      page: Enum.sort_by(page, & &1.id, :desc),
      total_count: count,
      page_info: %{
        start_cursor: start_cursor,
        end_cursor: end_cursor,
        has_next_page: not is_nil(end_cursor) and end_cursor < max_id,
        has_previous_page: not is_nil(start_cursor) and start_cursor > min_id
      }
    }
  end
end
