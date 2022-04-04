defmodule TdDdWeb.Resolvers.Templates do
  @moduledoc """
  Absinthe resolvers for templates
  """

  alias TdCache.TemplateCache

  def templates(_parent, args, _resolution) do
    case Map.get(args, :scope) do
      nil -> TemplateCache.list()
      scope -> TemplateCache.list_by_scope(scope)
    end
  end

  def updated_at(%{updated_at: value}, _args, _resolution) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, datetime}
      {:error, error} -> {:error, error}
    end
  end
end
