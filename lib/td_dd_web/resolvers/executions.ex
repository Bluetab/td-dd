defmodule TdDdWeb.Resolvers.Executions do
  @moduledoc """
  Absinthe resolvers for quality executions and related entities
  """

  alias TdDq.Executions

  def execution_groups_connection(%{id: user_id} = _me, args, _resolution) do
    args =
      args
      |> Map.take([:first, :last, :after, :before])
      |> Map.new(fn
        {:after, cursor} -> {:after, cursor}
        {:before, cursor} -> {:before, cursor}
        {:first, first} -> {:limit, first}
        {:last, last} -> {:limit, last}
      end)
      |> Map.put(:created_by_id, user_id)
      |> put_order_by(args)

    {:ok, connection(args)}
  end

  defp put_order_by(args, %{after: _}), do: Map.put(args, :order_by, :id)
  defp put_order_by(args, %{last: _}), do: Map.put(args, :order_by, desc: :id)
  defp put_order_by(args, %{}), do: Map.put(args, :order_by, :id)

  # see https://graphql.org/learn/pagination/
  defp connection(args) do
    args
    |> Executions.group_min_max_count()
    |> execution_groups_page(args)
  end

  defp execution_groups_page(%{count: 0}, _args) do
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

  defp execution_groups_page(%{min_id: min_id, max_id: max_id, count: count}, args) do
    page = Executions.list_groups(args)

    {start_cursor, end_cursor} =
      page
      |> Enum.map(& &1.id)
      |> Enum.min_max(fn -> {0, nil} end)

    %{
      page: Enum.sort_by(page, &(-&1.id)),
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
