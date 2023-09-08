defmodule TdDdWeb.Resolvers.Executions do
  @moduledoc """
  Absinthe resolvers for quality executions and related entities
  """

  alias TdDdWeb.Resolvers.Utils.CursorPagination
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
      |> CursorPagination.put_order_by(args)

    {:ok, executions_connection(args)}
  end

  def execution_groups_connection(%{id: user_id} = _me, args, _resolution) do
    args =
      args
      |> Map.take([:first, :last, :after, :before])
      |> Map.new(&connection_param/1)
      |> Map.put(:created_by_id, user_id)
      |> CursorPagination.put_order_by(args)

    {:ok, groups_connection(args)}
  end

  defp connection_param({:after, cursor}), do: {:after, cursor}
  defp connection_param({:before, cursor}), do: {:before, cursor}
  defp connection_param({:first, first}), do: {:limit, first}
  defp connection_param({:last, last}), do: {:limit, last}
  defp connection_param({:filters, filters}), do: {:filters, build_filters(filters)}

  defp build_filters(filters) do
    Map.new(filters, fn
      %{field: "status", values: values} -> {:status, values}
    end)
  end

  # see https://graphql.org/learn/pagination/
  defp groups_connection(args) do
    args
    |> Executions.group_min_max_count()
    |> CursorPagination.read_page(fn -> Executions.list_groups(args) end)
  end

  defp executions_connection(args) do
    args
    |> Executions.min_max_count()
    |> CursorPagination.read_page(fn -> Executions.list_executions(args) end)
    |> Map.put_new(:filters, Executions.execution_filters(args))
  end
end
