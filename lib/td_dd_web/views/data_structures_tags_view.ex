defmodule TdDdWeb.DataStructuresTagsView do
  use TdDdWeb, :view

  alias TdDdWeb.DataStructureTagView

  def render("show.json", %{link: link}) do
    %{data: render_one(link, __MODULE__, "data_structures_tags.json")}
  end

  def render("index.json", %{links: links}) do
    %{data: render_many(links, __MODULE__, "data_structures_tags.json")}
  end

  def render("data_structures_tags.json", %{data_structures_tags: %{} = data_structures_tags}) do
    data_structures_tags
    |> Map.take([:id, :comment, :inserted_at, :updated_at])
    |> put_embeddings(data_structures_tags)
  end

  def render("data_structures_tags.json", %{data_structures_tags: data_structures_tags})
      when is_binary(data_structures_tags) do
    data_structures_tags
  end

  defp put_embeddings(json, data_structures_tags) do
    data_structures_tags
    |> Map.take([:data_structure, :data_structure_tag])
    |> Enum.map(fn
      {:data_structure, structure} -> {:data_structure, structure_json(structure)}
      {:data_structure_tag, tag} -> {:data_structure_tag, structure_tag_json(tag)}
    end)
    |> maybe_put_embedded(json)
  end

  defp structure_json(data_structure) do
    Map.take(data_structure, [:id, :external_id])
  end

  defp structure_tag_json(data_structure_tag) do
    render_one(data_structure_tag, DataStructureTagView, "embedded.json")
  end

  defp maybe_put_embedded([] = _embedded, json), do: json

  defp maybe_put_embedded([_ | _] = embedded, json) do
    Map.put(json, :_embedded, Map.new(embedded))
  end
end
