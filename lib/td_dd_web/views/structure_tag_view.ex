defmodule TdDdWeb.StructureTagView do
  use TdDdWeb, :view

  alias TdDdWeb.TagView

  def render("show.json", %{link: link}) do
    %{data: render_one(link, __MODULE__, "structure_tag.json")}
  end

  def render("index.json", %{links: links}) do
    %{data: render_many(links, __MODULE__, "structure_tag.json")}
  end

  def render("structure_tag.json", %{structure_tag: %{} = structure_tag}) do
    structure_tag
    |> Map.take([:id, :comment, :inherit, :inserted_at, :updated_at])
    |> put_embeddings(structure_tag)
  end

  def render("structure_tag.json", %{structure_tag: structure_tag})
      when is_binary(structure_tag) do
    structure_tag
  end

  defp put_embeddings(json, structure_tag) do
    structure_tag
    |> Map.take([:data_structure, :tag])
    |> Enum.map(fn
      {:data_structure, structure} -> {:data_structure, structure_json(structure)}
      {:tag, tag} -> {:tag, tag_json(tag)}
    end)
    |> maybe_put_embedded(json)
  end

  defp structure_json(data_structure) do
    Map.take(data_structure, [:id, :external_id])
  end

  defp tag_json(tag) do
    render_one(tag, TagView, "embedded.json")
  end

  defp maybe_put_embedded([] = _embedded, json), do: json

  defp maybe_put_embedded([_ | _] = embedded, json) do
    Map.put(json, :_embedded, Map.new(embedded))
  end
end
