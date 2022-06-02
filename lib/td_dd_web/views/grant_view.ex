defmodule TdDdWeb.GrantView do
  use TdDdWeb, :view

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Systems.System
  alias TdDdWeb.DataStructureVersionView

  def render("index.json", %{grants: grants}) do
    %{data: render_many(grants, __MODULE__, "grant.json")}
  end

  def render("show.json", %{grant: grant}) do
    %{data: render_one(grant, __MODULE__, "grant.json")}
  end

  def render("grant.json", %{grant: grant}) do
    grant
    |> Map.take([
      :id,
      :detail,
      :start_date,
      :end_date,
      :pending_removal,
      :user_id,
      :source_user_name,
      :inserted_at,
      :updated_at
    ])
    |> add_structure(grant)
    |> add_structure_version(grant)
    |> add_system(grant)
    |> add_user(grant)
  end

  defp add_system(grant, %{system: %System{} = system}) do
    system = Map.take(system, [:external_id, :id, :name])
    Map.put(grant, :system, system)
  end

  defp add_system(grant, _), do: grant

  defp add_structure(grant, %{data_structure: %DataStructure{} = structure}) do
    structure = Map.take(structure, [:name, :external_id, :id, :system_id])
    Map.put(grant, :data_structure, structure)
  end

  defp add_structure(grant, _), do: grant

  defp add_structure_version(grant, %{data_structure_version: %DataStructureVersion{} = dsv}) do
    version =
      dsv
      |> DataStructureVersionView.add_ancestry()
      |> Map.take([:name, :ancestry])

    Map.put(grant, :data_structure_version, version)
  end

  defp add_structure_version(grant, %{
         data_structure_version: %{data_structure_id: _data_structure_id} = dsv
       }) do
    version =
      struct(DataStructureVersion, dsv)
      |> Map.take([
        :data_structure_id,
        :name,
        :description,
        :external_id,
        :metadata,
        :mutable_metadata
      ])
      |> Map.put(:domain, dsv.domain)

    Map.put(grant, :data_structure_version, version)
  end

  defp add_structure_version(grant, _), do: grant

  defp add_user(grant, %{user: %{} = user}) do
    user = Map.take(user, [:email, :full_name, :user_name])
    Map.put(grant, :user, user)
  end

  defp add_user(grant, _), do: grant
end
