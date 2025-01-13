defmodule TdDd.Search.StructureVersionEnricher do
  @moduledoc """
  Enriches data structure versions for bulk indexing
  """

  alias TdDd.Search.StructureEnricher

  def enricher(opts \\ []) do
    enricher(opts[:content], opts[:filters])
  end

  defp enricher(content_opt, %{} = metadata_filters) when map_size(metadata_filters) > 0 do
    fn %{data_structure: structure, type: type} = dsv ->
      filters = filters(dsv, Map.get(metadata_filters, type))

      %{
        dsv
        | data_structure: StructureEnricher.enrich(structure, type, content_opt),
          _filters: filters
      }
    end
  end

  defp enricher(content_opt, _) do
    fn %{data_structure: structure, type: type} = dsv ->
      %{dsv | data_structure: StructureEnricher.enrich(structure, type, content_opt)}
    end
  end

  defp filters(%{} = dsv, filters) when is_list(filters) and length(filters) > 0 do
    dsv
    |> Map.take([:metadata, :mutable_metadata])
    |> Map.values()
    |> Enum.filter(&is_map/1)
    |> do_filters(filters)
    |> Enum.filter(fn {_, v} -> primitive?(v) end)
    |> Map.new()
  end

  defp filters(_, _), do: nil

  defp do_filters([], _filters), do: nil
  defp do_filters([m], filters), do: Map.take(m, filters)

  defp do_filters([m1, m2], filters) do
    m1
    |> Map.merge(m2)
    |> Map.take(filters)
  end

  defp primitive?(v) when is_binary(v), do: true
  defp primitive?(v) when is_boolean(v), do: true
  defp primitive?(v) when is_number(v), do: true
  defp primitive?([v | _]), do: primitive?(v)
  defp primitive?(_), do: false
end
