defmodule TdCxWeb.SourceView do
  use TdCxWeb, :view
  alias TdCx.Format
  alias TdCxWeb.SourceView

  def render("index.json", %{sources: sources}) do
    %{data: render_many(sources, SourceView, "source.json")}
  end

  def render("show.json", %{source: source} = assigns) do
    %{data: render_one(source, SourceView, "source.json", Map.delete(assigns, :source))}
  end

  def render("embedded.json", %{source: source}) do
    Map.take(source, [:id, :external_id, :type, :active])
  end

  def render("source.json", %{source: source} = assigns) do
    config = Map.get(source, :config)
    job_types = Map.get(assigns, :job_types)

    %{
      id: source.id,
      external_id: source.external_id,
      type: source.type,
      active: source.active
    }
    |> add_cached_content(config)
    |> add_job_types(job_types)
  end

  defp add_cached_content(source, nil), do: add_cached_content(source, %{})

  defp add_cached_content(source, %{} = config) do
    template = Map.get(source, :type)
    config = Format.get_cached_content(config, template)

    Map.put(source, :config, config)
  end

  defp add_job_types(source, nil), do: source
  defp add_job_types(source, job_types), do: Map.put(source, :job_types, job_types)
end
