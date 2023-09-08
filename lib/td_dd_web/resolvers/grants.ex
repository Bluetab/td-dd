defmodule TdDdWeb.Resolvers.Grants do
  @moduledoc """
  Absinthe resolvers for grant requests
  """

  alias TdDd.Grants
  alias TdDdWeb.Resolvers.Utils.CursorPagination

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
      |> CursorPagination.put_order_by(args)

    {:ok, get_grants(cursor_args, opts)}
  end

  defp connection_param({:after, cursor}), do: {:after, cursor}
  defp connection_param({:before, cursor}), do: {:before, cursor}
  defp connection_param({:first, first}), do: {:limit, first}
  defp connection_param({:last, last}), do: {:limit, last}
  defp connection_param({:filters, filters}), do: {:filters, filters}

  defp get_grants(args, opts) do
    args
    |> Grants.min_max_count()
    |> CursorPagination.read_page(fn ->
      args
      |> maybe_preload(opts)
      |> Grants.list_grants(opts)
    end)
  end

  defp maybe_preload(args, []), do: args

  defp maybe_preload(args, opts) do
    Map.put(args, :preload, opts[:preload])
  end
end
