defmodule TdCxWeb.SourceView do
  use TdCxWeb, :view
  alias TdCxWeb.SourceView

  def render("index.json", %{sources: sources}) do
    %{data: render_many(sources, SourceView, "source.json")}
  end

  def render("show.json", %{source: source}) do
    %{data: render_one(source, SourceView, "source.json")}
  end

  def render("source.json", %{source: source}) do
    %{id: source.id,
      type: source.type,
      external_id: source.external_id,
      secrets: source.secrets,
      config: source.config}
  end
end
