defmodule TdDd.Repo.Migrations.LinkStructuresToSystems do
  use Ecto.Migration

  import Ecto.Query

  alias TdDd.Repo

  def change do
    from(s in "systems", select: %{id: s.id, external_ref: s.external_ref})
    |> Repo.all()
    |> Enum.each(&update_system_id/1)
  end

  defp update_system_id(%{id: id, external_ref: external_ref}) do
    from(
      ds in "data_structures", 
      update: [set: [system_id: ^id]], 
      where: ds.system == ^external_ref
    )
    |> Repo.update_all([])
  end
end
