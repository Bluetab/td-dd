defmodule TdDdWeb.Resolvers.Grants do
  @moduledoc """
  Absinthe resolvers for grant requests
  """

  alias TdDd.Grants

  def grants(_parent, args, _resolution) do
    args =
      args
      |> Map.take([:first, :last, :after, :before, :filters])
      |> Map.new(&connection_param/1)
      |> put_order_by(args)

    {:ok, get_grants(args)}
  end

  defp connection_param({:after, cursor}), do: {:after, cursor}
  defp connection_param({:before, cursor}), do: {:before, cursor}
  defp connection_param({:first, first}), do: {:limit, first}
  defp connection_param({:last, last}), do: {:limit, last}
  defp connection_param({:filters, filters}), do: {:filters, filters}

  defp put_order_by(args, %{after: _}), do: Map.put(args, :order_by, :id)
  defp put_order_by(args, %{last: _}), do: Map.put(args, :order_by, desc: :id)
  defp put_order_by(args, %{}), do: Map.put(args, :order_by, :id)

  defp get_grants(args) do
    args
    |> Grants.min_max_count()
    |> read_page(fn -> Grants.list_grants(args) end)
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

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil

end
