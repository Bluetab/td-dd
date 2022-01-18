defmodule TdDdWeb.Resolvers.Sources do
  @moduledoc """
  Absinthe resolvers for data sources and related entities
  """

  alias TdCache.TemplateCache
  alias TdCx.Sources

  def sources(_parent, args, _resolution) do
    {:ok, Sources.query_sources(args)}
  end

  def source(_parent, args, _resolution) do
    {:ok, Sources.get_source(args)}
  end

  def template(%{type: source_type}, _args, _resolution) do
    TemplateCache.get_by_name(source_type)
  end
end
