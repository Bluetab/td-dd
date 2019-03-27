defmodule TdDd.Repo.Migrations.LinkStructuresToSystems do
  use Ecto.Migration

  import Ecto.Query

  alias TdDd.Repo

  def change do
    from(s in "systems", select: %{id: s.id, external_id: s.external_id})
    |> Repo.all()
    |> Enum.each(&update_system_id/1)
  end

  defp update_system_id(%{id: id, external_id: external_id}) do
    from(
      ds in "data_structures", 
      update: [set: [system_id: ^id]], 
      where: ds.system == ^external_id
    )
    |> Repo.update_all([])
  end
end
