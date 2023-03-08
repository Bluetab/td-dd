defmodule TdCx.Format do
  @moduledoc """
  Manages content formatting
  """
  alias TdCache.TemplateCache
  alias TdDfLib.Format

  def get_cached_content(%{} = content, type) when is_binary(type) do
    case TemplateCache.get_by_name!(type) do
      template = %{} ->
        Format.enrich_content_values(content, template, [:domain, :system, :hierarchy])

      _ ->
        content
    end
  end

  def get_cached_content(content, _type), do: content
end
