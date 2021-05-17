defmodule TdDd.Repo.Migrations.AddProfileFromStructure do
  use Ecto.Migration

  import Ecto.Query

  alias TdDd.Repo

  def change do
    structures = structures_with_profile()
    create_profiles(structures)
    update_structures(structures)
  end

  defp structures_with_profile do
    from(dsv in "data_structure_versions")
    |> select([dsv], [:id, :metadata, :data_structure_id, :version])
    |> Repo.all()
    |> Enum.filter(fn %{metadata: metadata} -> Map.has_key?(metadata, "profile") end)
  end

  defp create_profiles(structures) do
    profiles =
      structures
      |> Enum.group_by(& &1.data_structure_id)
      |> Enum.map(fn {_k, values} -> Enum.max_by(values, & &1.version) end)
      |> Enum.map(fn %{data_structure_id: data_structure_id, metadata: metadata} ->
        value = Map.get(metadata, "profile")
        now = DateTime.utc_now()
        %{data_structure_id: data_structure_id, value: value, inserted_at: now, updated_at: now}
      end)

    Repo.insert_all("profiles", profiles)
  end

  defp update_structures(structures) do
    structures
    |> Enum.map(fn dsv ->
      metadata =
        dsv
        |> Map.get(:metadata)
        |> Map.delete("profile")

      dsv
      |> Map.put(:metadata, metadata)
      |> Map.put(:hash, nil)
      |> Map.put(:lhash, nil)
      |> Map.put(:ghash, nil)
    end)
    |> Enum.map(&update_structure/1)
  end

  defp update_structure(%{id: id, metadata: metadata, hash: hash, lhash: lhash, ghash: ghash}) do
    from(dsv in "data_structure_versions")
    |> where([dsv], dsv.id == ^id)
    |> update([dsv], set: [metadata: ^metadata, hash: ^hash, lhash: ^lhash, ghash: ^ghash])
    |> Repo.update_all([])
  end
end
