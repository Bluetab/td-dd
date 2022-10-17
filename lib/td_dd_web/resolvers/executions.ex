defmodule TdDdWeb.Resolvers.Executions do
  @moduledoc """
  Absinthe resolvers for quality executions and related entities
  """

  alias TdDq.Executions

  def executions_filters(%{implementation_ref: ref} = _implementation, _args, _resolution) do
    {:ok, Executions.execution_filters(%{ref: ref})}
  end

  def executions_connection(%{implementation_ref: ref} = _implementation, args, _resolution) do
    args =
      args
      |> Map.take([:first, :last, :after, :before, :filters])
      |> Map.new(&connection_param/1)
      |> Map.put(:ref, ref)
      |> put_order_by(args)

    {:ok, executions_connection(args)}
  end

  def execution_groups_connection(%{id: user_id} = _me, args, _resolution) do
    args =
      args
      |> Map.take([:first, :last, :after, :before])
      |> Map.new(&connection_param/1)
      |> Map.put(:created_by_id, user_id)
      |> put_order_by(args)

    {:ok, groups_connection(args)}
  end

  defp connection_param({:after, cursor}), do: {:after, cursor}
  defp connection_param({:before, cursor}), do: {:before, cursor}
  defp connection_param({:first, first}), do: {:limit, first}
  defp connection_param({:last, last}), do: {:limit, last}
  defp connection_param({:filters, filters}), do: {:filters, build_filters(filters)}

  defp put_order_by(args, %{after: _}), do: Map.put(args, :order_by, :id)
  defp put_order_by(args, %{last: _}), do: Map.put(args, :order_by, desc: :id)
  defp put_order_by(args, %{}), do: Map.put(args, :order_by, :id)

  defp build_filters(filters) do
    Map.new(filters, fn
      %{field: "status", values: values} -> {:status, values}
    end)
  end

  # see https://graphql.org/learn/pagination/
  defp groups_connection(args) do
    args
    |> Executions.group_min_max_count()
    |> read_page(fn -> Executions.list_groups(args) end)
  end

  defp executions_connection(args) do
    args
    |> Executions.min_max_count()
    |> read_page(fn -> Executions.list_executions(args) end)
    |> Map.put_new(:filters, Executions.execution_filters(args))
  end

  defp read_page(%{count: 0}, _fun) do
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

  defp read_page(%{count: count, min_id: min_id, max_id: max_id}, fun) do
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
