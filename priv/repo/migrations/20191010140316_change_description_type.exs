defmodule TdDq.Repo.Migrations.ChangeDescriptionType do
  use Ecto.Migration
  import Ecto.Query
  alias TdDd.Repo

  def change do
    rename table("rules"), :description, to: :description_backup
    alter table("rules"), do: add(:description, :map)

    flush()

    migrate_descriptions()
    alter table("rules"), do: remove(:description_backup)
  end

  defp migrate_descriptions do
    from(r in "rules")
    |> select([r], %{id: r.id, description: r.description_backup})
    |> Repo.all()
    |> Enum.map(&description_to_map/1)
    |> Enum.each(&update_description/1)
  end

  defp description_to_map(%{description: description} = attrs) do
    description = description || ""
    Map.put(attrs, :description, to_map(description))
  end

  defp to_map(""), do: %{}

  defp to_map(description) do
    nodes =
      description
      |> String.split("\n")
      |> Enum.map(&build_node/1)

    %{document: %{nodes: nodes}}
  end

  defp build_node(text) do
    %{
      object: "block",
      type: "paragraph",
      nodes: [%{object: "text", leaves: [%{text: text}]}]
    }
  end

  defp update_description(%{id: id, description: description}) do
    from(r in "rules")
    |> where([r], r.id == ^id)
    |> update(set: [description: ^description])
    |> Repo.update_all([])
  end
end
