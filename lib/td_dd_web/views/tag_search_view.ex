defmodule TdDdWeb.TagSearchView do
  use TdDdWeb, :view

  def render("index.json", %{tags: tags}) do
    %{
      data: render_many(tags, __MODULE__, "tag.json")
    }
  end

  def render("tag.json", %{tag_search: tag}) do
    Map.take(tag, [
      :id,
      :name,
      :description,
      :domain_ids,
      :inserted_at,
      :updated_at
    ])
  end
end
