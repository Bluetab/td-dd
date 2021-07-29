defmodule TdDdWeb.GrantView do
  use TdDdWeb, :view
  alias TdDd.DataStructures.{DataStructure, DataStructureVersion}
  alias TdDdWeb.{DataStructureVersionView, DataStructureView, GrantView}

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
    |> add_structure_version(grant)
    |> add_user(grant)
  end

  defp add_structure(response, %{data_structure: %DataStructure{} = structure}) do
    structure = render_one(structure, DataStructureView, "data_structure.json")

    Map.put(
      response,
      :data_structure,
      Map.take(structure, [:name, :external_id, :id, :system_id, :system])
    )
  end

  defp add_structure(response, _), do: response

  defp add_structure_version(response, %{data_structure_version: %DataStructureVersion{} = dsv}) do
    version = render_one(dsv, DataStructureVersionView, "version.json")

    Map.put(
      response,
      :data_structure_version,
      Map.take(version, [:name, :ancestry])
    )
  end

  defp add_structure_version(response, _), do: response

  defp add_user(response, %{user: %{} = user}) do
    Map.put(
      response,
      :data_structure_version,
      Map.take(user, [:full_name, :user_name])
    )
  end

  defp add_user(response, _), do: response
end
