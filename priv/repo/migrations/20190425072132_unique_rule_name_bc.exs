defmodule TdDq.Repo.Migrations.UniqueRuleNameBc do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias TdDq.Repo
  alias TdDq.Rules.Rule

  def change do
    Rule
    |> group_by([r], [r.business_concept_id, r.name])
    |> having([r], count(r.name) > 1)
    |> select([r], {r.name, r.business_concept_id})
    |> Repo.all()
    |> Enum.map(&get_rules(&1))
    |> Enum.map(&get_tail(&1))
    |> Enum.map(&update_names(&1))
    |> List.flatten()
    |> Enum.map(&do_update(&1))
  end

  defp get_rules({name, bc_id}) do
    Rule
    |> filter_by_name_and_bc_id(name, bc_id)
    |> select([r], {r.id, r.name})
    |> Repo.all()
  end

  defp filter_by_name_and_bc_id(query, name, nil) do
    query |> where([r], is_nil(r.business_concept_id) and r.name == ^name)
  end

  defp filter_by_name_and_bc_id(query, name, id) do
    query |> where([r], r.name == ^name and r.business_concept_id == ^id)
  end

  defp get_tail([_ | tail]), do: tail

  defp update_names(duplicated_rules) do
    Enum.reduce(0..(length(duplicated_rules) - 1), [], fn i, acc ->
      {id, name} = Enum.at(duplicated_rules, i)
      updated_name = "#{name} #{i + 1}"
      acc ++ [{id, updated_name}]
    end)
  end

  defp do_update({id, name}) do
    Rule
    |> where([r], r.id == ^id)
    |> update([u], set: [name: ^name])
    |> Repo.update_all([])
  end
end
