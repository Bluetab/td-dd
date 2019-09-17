defmodule TdDd.Repo.Migrations.AddProfileFromStructure do
  use Ecto.Migration

  import Ecto.Query, warn: false

  alias TdDd.Repo

  def change do
    profiles =
      from(dsv in "data_structure_versions")
      |> select([dsv], [:metadata, :data_structure_id, :version])
      |> Repo.all()
      |> Enum.filter(fn %{metadata: metadata} -> Map.has_key?(metadata, "profile") end)
      |> Enum.group_by(& &1.data_structure_id)
      |> Enum.map(fn {_k, values} -> Enum.max_by(values, & &1.version) end)
      |> Enum.map(fn %{data_structure_id: data_structure_id, metadata: metadata} ->
        value = Map.get(metadata, "profile")
        now = DateTime.utc_now()
        %{data_structure_id: data_structure_id, value: value, inserted_at: now, updated_at: now}
      end)

    Repo.insert_all("profiles", profiles)
  end
end
