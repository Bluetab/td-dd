defmodule TdCxWeb.SourceView do
  use TdCxWeb, :view
  alias TdCx.Format
  alias TdCxWeb.SourceView

  def render("index.json", %{sources: sources}) do
    %{data: render_many(sources, SourceView, "source.json")}
  end

  def render("show.json", %{source: source}) do
    %{data: render_one(source, SourceView, "source.json")}
  end

  def render("source.json", %{source: source}) do
    %{
      id: source.id,
      external_id: source.external_id,
      config: Map.get(source, :config, %{}) || %{},
      type: source.type,
      active: source.active
    }
    |> add_cached_content()
  end

  defp add_cached_content(source) do
    type = Map.get(source, :type)

    config =
      source
      |> Map.get(:config)
      |> Format.get_cached_content(type)

    Map.put(source, :config, config)
  end
end
