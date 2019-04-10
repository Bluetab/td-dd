defmodule TdDd.Repo.Migrations.LinkStructuresToSystems do
  use Ecto.Migration

  import Ecto.Query

  alias TdDd.Repo
  alias TdDd.Systems.System

  def up do
    System
    |> Repo.all()
    |> Enum.map(&Map.take(&1, [:name, :id]))
    |> Enum.each(&update_system_id/1)
  end

  def down do
    from(
      ds in "data_structures",
      update: [set: [system_id: nil]]
    )
    |> Repo.update_all([])
  end

  defp update_system_id(%{id: id, name: name}) do
    from(
      ds in "data_structures",
      update: [set: [system_id: ^id]],
      where: ds.system == ^name
    )
    |> Repo.update_all([])
  end
end
