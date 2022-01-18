defmodule TdDdWeb.Resolvers.Sources do
  @moduledoc """
  Absinthe resolvers for data sources and related entities
  """

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
end
