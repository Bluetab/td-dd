defmodule TdDdWeb.Resolvers.Grants do
  @moduledoc """
  Absinthe resolvers for grant requests
  """

  alias TdDd.Grants

  @enrich_fields [:dsv_children]
  @preload_fields [:data_structure, :data_structure_version]

  def grants(_parent, args, resolution) do
    opts =
      resolution
      |> Map.get(:definition)
      |> Map.get(:selections)
      |> Enum.find(fn field -> field.name === "page" end)
      |> Map.get(:selections)
      |> Enum.map(fn %{schema_node: %{identifier: identifier}} -> identifier end)
      |> Enum.reduce(
        [preload: [], enrich: []],
        fn
          field, acc when field in @preload_fields ->
            Keyword.put(acc, :preload, acc[:preload] ++ [field])

          field, acc when field in @enrich_fields ->
            Keyword.put(acc, :enrich, acc[:enrich] ++ [field])

          _, acc ->
            acc
        end
      )

    cursor_args =
      args
      |> Map.take([:first, :last, :after, :before, :filters])
      |> Map.new(&connection_param/1)
      |> put_order_by(args)

    {:ok, get_grants(cursor_args, opts)}
  end

  defp connection_param({:after, cursor}), do: {:after, cursor}
  defp connection_param({:before, cursor}), do: {:before, cursor}
  defp connection_param({:first, first}), do: {:limit, first}
  defp connection_param({:last, last}), do: {:limit, last}
  defp connection_param({:filters, filters}), do: {:filters, filters}

  defp put_order_by(args, %{after: _}), do: Map.put(args, :order_by, :id)
  defp put_order_by(args, %{last: _}), do: Map.put(args, :order_by, desc: :id)
  defp put_order_by(args, %{}), do: Map.put(args, :order_by, :id)

  defp get_grants(args, opts) do
    args
    |> Grants.min_max_count()
    |> read_page(fn ->
      args
      |> maybe_preload(opts)
      |> Grants.list_grants(opts)
    end)
  end

  defp maybe_preload(args, []), do: args

  defp maybe_preload(args, opts) do
    Map.put(args, :preload, opts[:preload])
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
