defmodule TdDdWeb.GrantView do
  use TdDdWeb, :view
  alias TdDdWeb.GrantView

  def render("index.json", %{grants: grants}) do
    %{data: render_many(grants, GrantView, "grant.json")}
  end

  def render("show.json", %{grant: grant}) do
    %{data: render_one(grant, GrantView, "grant.json")}
  end

  def render("grant.json", %{grant: grant}) do
    %{
      id: grant.id,
      detail: grant.detail,
      start_date: grant.start_date,
      end_date: grant.end_date,
      user_id: grant.user_id
    }
  end
end
