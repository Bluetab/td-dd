defmodule TdDq.Repo.Migrations.ChangeResultRounding do
  use Ecto.Migration
  import Ecto.Query
  alias TdDq.Repo

  def change do
    from(rr in "rule_results")
    |> where([rr], not is_nil(rr.records) and not is_nil(rr.errors))
    |> select([rr], %{id: rr.id, records: rr.records, errors: rr.errors})
    |> Repo.all()
    |> Enum.map(&caculate_result/1)
    |> Enum.map(&update/1)
  end

  defp caculate_result(%{records: 0} = rr) do
    Map.put(rr, :result, 0)
  end

  defp caculate_result(%{records: records, errors: errors} = rr) do
    scale = 2
    result = Decimal.from_float(abs((records - errors) / records) * 100)
    Map.put(rr, :result, Decimal.round(result, scale, :floor))
  end

  defp update(%{id: id, result: result}) do
    from(rr in "rule_results")
    |> where([rr], rr.id == ^id)
    |> update(set: [result: ^result])
    |> Repo.update_all([])
  end
end
