defmodule TdDq.Repo.Migrations.DeleteStructureAttrsFromSystemParams do
  use Ecto.Migration

  import Ecto.Query

  alias TdDd.Repo

  def change do
    rule_types =
      from(rt in "rule_types")
      |> select([rt], %{id: rt.id, params: rt.params})
      |> Repo.all()
      |> Enum.filter(&of_type_structure/1)

    rule_types_ids = Enum.map(rule_types, &Map.get(&1, :id))

    from(ri in "rule_implementations")
    |> join(:inner, [ri, r], r in "rules", on: r.id == ri.rule_id)
    |> join(:inner, [_, r, rt], rt in "rule_types", on: rt.id == r.rule_type_id)
    |> where([ri, _, _], is_nil(ri.deleted_at))
    |> where([_, r, _], is_nil(r.deleted_at))
    |> where([_, _, rt], rt.id in ^rule_types_ids)
    |> select([ri, _, rt], %{
      id: ri.id,
      system_params: ri.system_params,
      rule_type_id: rt.id,
      rule_type_params: rt.params
    })
    |> Repo.all()
    |> Enum.map(&delete_structure_params/1)
    |> Enum.map(&update_system_params/1)
  end

  defp of_type_structure(%{params: %{"system_params" => system_params}})
       when system_params == %{},
       do: false

  defp of_type_structure(%{params: nil}), do: false

  defp of_type_structure(%{params: %{"system_params" => system_params}}) do
    Enum.any?(system_params, &is_structure_type(&1))
  end

  defp of_type_structure(%{params: %{}}), do: false

  defp is_structure_type(system_params) do
    Map.get(system_params, "type") == "structure"
  end

  defp delete_structure_params(%{
         id: id,
         system_params: system_params,
         rule_type_params: %{"system_params" => rule_type_params}
       }) do
    type_params_names =
      rule_type_params
      |> Enum.filter(fn param -> Map.get(param, "type") == "structure" end)
      |> Enum.map(fn param -> Map.get(param, "name") end)

    new_system_params =
      system_params
      |> Enum.filter(fn {key, value} ->
        key in type_params_names and Map.has_key?(value, "id")
      end)
      |> Enum.map(fn {key, value} ->
        param = %{"id" => Map.get(value, "id"), "name" => Map.get(value, "name", "")}
        {key, param}
      end)
      |> Enum.into(system_params)

    %{id: id, system_params: new_system_params}
  end

  defp update_system_params(%{id: id, system_params: system_params}) do
    from(ri in "rule_implementations")
    |> update([ri], set: [system_params: ^system_params])
    |> where([ri], ri.id == ^id)
    |> Repo.update_all([])
  end
end
