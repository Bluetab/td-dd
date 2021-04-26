defmodule TdDdWeb.SystemView do
  use TdDdWeb, :view
  alias TdDdWeb.SystemView

  def render("index.json", %{systems: systems}) do
    %{data: render_many(systems, SystemView, "system.json")}
  end

  def render("show.json", %{system: system}) do
    %{data: render_one(system, SystemView, "system.json")}
  end

  def render("system.json", %{system: %{structures_count: structures_count} = system}) do
    %{
      id: system.id,
      name: system.name,
      df_content: system.df_content,
      external_id: system.external_id,
      structures_count: structures_count
    }
  end

  def render("system.json", %{system: system}) do
    %{
      id: system.id,
      name: system.name,
      external_id: system.external_id,
      df_content: system.df_content
    }
  end
end
