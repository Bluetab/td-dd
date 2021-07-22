defmodule TdDdWeb.GrantView do
  use TdDdWeb, :view
  alias TdDd.DataStructures.DataStructure
  alias TdDdWeb.DataStructureView
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
    |> add_structure(grant)
  end

  defp add_structure(response, %{data_structure: %DataStructure{} = structure}) do
    structure = render_one(structure, DataStructureView, "data_structure.json")
    Map.put(response, :data_structure, structure)
  end

  defp add_structure(response, _), do: response
end
