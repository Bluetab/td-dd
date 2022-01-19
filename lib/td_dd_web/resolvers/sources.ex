defmodule TdDdWeb.Resolvers.Sources do
  @moduledoc """
  Absinthe resolvers for data sources and related entities
  """

  import Canada, only: [can?: 2]

  alias TdCache.TemplateCache
  alias TdCx.Format
  alias TdCx.Sources

  def sources(_parent, args, _resolution) do
    {:ok, Sources.query_sources(args)}
  end

  def source(_parent, args, _resolution) do
    {:ok, Sources.get_source(args)}
  end

  def template(%{type: type}, _args, _resolution) do
    TemplateCache.get_by_name(type)
  end

  def config(%{type: type, config: config}, _args, _resolution) do
    {:ok, Format.get_cached_content(config, type)}
  end

  def enable_source(parent, %{id: id} = _args, resolution) do
    update_source(parent, %{source: %{id: id, active: true}}, resolution)
  end

  def disable_source(parent, %{id: id} = _args, resolution) do
    update_source(parent, %{source: %{id: id, active: false}}, resolution)
  end

  def update_source(_parent, %{source: %{id: id} = args}, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:source, %{} = source} <- {:source, Sources.get_source(id: id)},
         {:can, true} <- {:can, can?(claims, update(source))} do
      Sources.update_source(source, args)
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:source, nil} -> {:error, :not_found}
      {:can, false} -> {:error, :forbidden}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
