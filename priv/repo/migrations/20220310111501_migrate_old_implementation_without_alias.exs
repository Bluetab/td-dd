defmodule TdDd.Repo.Migrations.MigrateOldImplementationWithoutAlias do
  use Ecto.Migration
  import Ecto.Query, only: [from: 2]

  alias Ecto.Adapters.SQL
  alias TdDd.Repo

  @update_dataset """
  UPDATE rule_implementations
  SET dataset = $1
  WHERE id = $2
  """

  def up do
    from(ri in "rule_implementations",
      select: %{id: ri.id, rule_id: ri.rule_id, dataset: ri.dataset},
      where: fragment("? != '{}'", ri.dataset)
    )
    |> Repo.all()
    |> Enum.map(&add_alias_implementation/1)
    |> Enum.filter(&(not is_nil(&1)))
    |> Enum.each(&execute_update/1)
  end

  defp execute_update(%{id: id, dataset: dataset}) do
    SQL.query(Repo, @update_dataset, [dataset, id])
  end

  defp add_alias_implementation(%{dataset: dataset} = ri) do
    dataset
    |> add_alias_in_dataset()
    |> case do
      nil -> nil
      new_dataset -> Map.put(ri, :dataset, new_dataset)

    end
  end

  defp add_alias_in_dataset(dataset), do: add_alias_in_dataset(dataset, 1, [])

  defp add_alias_in_dataset([%{"alias" => _alias}], _index, []), do: nil

  defp add_alias_in_dataset([], _index, result), do: Enum.reverse(result)

  defp add_alias_in_dataset([%{"structure" => structure} = tuple | tail], index, result) do
    tuple = Map.put(tuple, "alias", %{"text" => nil, "index" => index})
    add_alias_in_dataset(tail, index + 1, [tuple | result])
  end
end
