defmodule TdDq.Repo.Migrations.MigrateDatasetJoinsToNewFormat do
  use Ecto.Migration
  import Ecto.Query, only: [from: 2]

  alias Ecto.Adapters.SQL
  alias TdDq.Repo

  @update_statement """
    UPDATE rule_implementations
    SET dataset = $1
    WHERE id = $2
  """
  def up do
    from(r in "rule_implementations",
      select: %{id: r.id, dataset: r.dataset}
    )
    |> Repo.all()
    |> Enum.map(&rule_implementation_to_clauses/1)
    |> Enum.each(&execute_update/1)
  end

  def down do
    from(r in "rule_implementations",
      select: %{id: r.id, dataset: r.dataset}
    )
    |> Repo.all()
    |> Enum.map(&rule_implementation_from_clauses/1)
    |> Enum.each(&execute_update/1)
  end

  defp execute_update(%{id: id, dataset: dataset}) do
    SQL.query(Repo, @update_statement, [dataset, id])
  end

  defp rule_implementation_to_clauses(%{dataset: dataset} = ri) do
    new_dataset = Enum.map(dataset, &structure_to_clauses/1)
    Map.put(ri, :dataset, new_dataset)
  end

  defp rule_implementation_from_clauses(%{dataset: dataset} = ri) do
    new_dataset = Enum.map(dataset, &structure_from_clauses/1)
    Map.put(ri, :dataset, new_dataset)
  end

  defp structure_to_clauses(
         %{"left" => %{"id" => left_id}, "right" => %{"id" => right_id}} = structure
       ) do
    structure
    |> Map.drop(["left", "right"])
    |> Map.put("clauses", [
      %{"left" => %{"id" => left_id}, "right" => %{"id" => right_id}}
    ])
  end

  defp structure_to_clauses(%{"clauses" => _clauses} = structure), do: structure

  defp structure_to_clauses(structure) do
    structure
    |> Map.drop(["left", "right"])
    |> Map.put("clauses", [])
  end

  defp structure_from_clauses(%{"clauses" => []} = structure) do
    structure
    |> Map.drop(["clauses"])
    |> Map.put("left", nil)
    |> Map.put("right", nil)
  end

  defp structure_from_clauses(
         %{
           "clauses" => [
             %{"left" => %{"id" => left_id}, "right" => %{"id" => right_id}} | _
           ]
         } = structure
       ) do
    structure
    |> Map.drop(["clauses"])
    |> Map.put("left", %{"id" => left_id})
    |> Map.put("right", %{"id" => right_id})
  end

  defp structure_from_clauses(structure), do: structure
end
