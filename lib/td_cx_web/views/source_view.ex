defmodule TdCxWeb.SourceView do
  use TdCxWeb, :view
  alias TdCxWeb.SourceView

  def render("index.json", %{sources: sources}) do
    %{data: render_many(sources, SourceView, "source.json")}
  end

  def render("index_with_secrets.json", %{sources: sources}) do
    %{data: render_many(sources, SourceView, "source_with_secrets.json")}
  end

  def render("show.json", %{source: source}) do
    %{data: render_one(source, SourceView, "source.json")}
  end

  def render("show_with_secrets.json", %{source: source}) do
    %{data: render_one(source, SourceView, "source_with_secrets.json")}
  end

  def render("source_with_secrets.json", %{source: source}) do
    %{
      id: source.id,
      external_id: source.external_id,
      config: Map.get(source, :config, %{}) || %{},
      secrets_key: Map.get(source, :secrets_key),
      secrets: Map.get(source, :secrets),
      type: source.type
    }
  end

  def render("source.json", %{source: source}) do
    %{
      id: source.id,
      external_id: source.external_id,
      config: Map.get(source, :config, %{}) || %{},
      type: source.type
    }
  end
end
